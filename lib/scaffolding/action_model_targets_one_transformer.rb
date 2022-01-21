require_relative "transformer"
require_relative "block_manipulator"

class Scaffolding::ActionModelTargetsOneTransformer < Scaffolding::Transformer
  attr_accessor :action

  def initialize(action, child, parents, cli_options = {})
    super(child, parents, cli_options)
    self.action = action
  end

  def add_locale_helper_export_fix
    namespaced_locale_export_hook = "# 🚅 super scaffolding will insert the export for the locale view helper here."

    spacer = "  "
    indentation = spacer * 3
    namespace_elements = child.underscore.pluralize.split("/")
    first_element = namespace_elements.shift
    lines_to_add = [first_element + ":"]
    namespace_elements.map do |namespace_element|
      lines_to_add << indentation + namespace_element + ":"
      indentation += spacer
    end

    lines_to_add << transform_string("#{indentation}targets_one_actions: *targets_one_actions")

    scaffold_replace_line_in_file("./config/locales/en/scaffolding/completely_concrete/tangible_things/targets_one_actions.en.yml", lines_to_add.join("\n"), namespaced_locale_export_hook)
  end

  RUBY_NEW_ACTION_MODEL_BUTTONS_PROCESSING_HOOK = "<%# 🚅 super scaffolding will insert new action model buttons above this line. %>"
  RUBY_NEW_BULK_ACTION_MODEL_BUTTONS_PROCESSING_HOOK = "<%# 🚅 super scaffolding will insert new bulk action model buttons above this line. %>"
  RUBY_NEW_ACTION_MODEL_INDEX_VIEWS_PROCESSING_HOOK = "<%# 🚅 super scaffolding will insert new action model index views above this line. %>"

  def scaffold_action_model
    add_parent_model_action_model_hooks

    files = [
      "./app/models/scaffolding/completely_concrete/tangible_things/targets_one_action.rb",
      "./app/serializers/api/v1/scaffolding/completely_concrete/tangible_things/targets_one_action_serializer.rb",
      "./app/controllers/api/v1/scaffolding/completely_concrete/tangible_things/targets_one_actions_endpoint.rb",
      "./app/controllers/account/scaffolding/completely_concrete/tangible_things/targets_one_actions_controller.rb",
      "./app/views/account/scaffolding/completely_concrete/tangible_things/targets_one_actions",
      "./test/models/scaffolding/completely_concrete/tangible_things/targets_one_action_test.rb",
      "./test/factories/scaffolding/completely_concrete/tangible_things/targets_one_actions.rb",
      "./test/controllers/api/v1/scaffolding/completely_concrete/tangible_things/targets_one_actions_endpoint_test.rb",
      "./config/locales/en/scaffolding/completely_concrete/tangible_things/targets_one_actions.en.yml",
    ]

    files.each do |name|
      if File.directory?(name)
        scaffold_directory(name)
      else
        scaffold_file(name)
      end
    end

    add_locale_helper_export_fix

    # Add the action button to the target _index partial
    target_index_file = "./app/views/account/scaffolding/completely_concrete/tangible_things/_index.html.erb"
    scaffold_add_line_to_file(
      target_index_file,
      "<%= render \"account/scaffolding/completely_concrete/tangible_things/targets_one_actions/new_button_one\", tangible_thing: tangible_thing %>",
      RUBY_NEW_ACTION_MODEL_BUTTONS_PROCESSING_HOOK,
      prepend: true
    )

    # TODO I think this needs to be the show view, yes?
    # # Add the action index partial to the target _index partial
    # scaffold_add_line_to_file(
    #   target_index_file,
    #   "<%= render 'account/scaffolding/completely_concrete/tangible_things/targets_one_actions/index', targets_one_actions: context.completely_concrete_tangible_things_targets_one_actions, hide_back: true %>",
    #   RUBY_NEW_ACTION_MODEL_INDEX_VIEWS_PROCESSING_HOOK,
    #   prepend: true
    # )

    # Add the has_many to the target model.
    scaffold_add_line_to_file(
      "./app/models/scaffolding/completely_concrete/tangible_thing.rb",
      "has_many :targets_one_actions, class_name: \"Scaffolding::CompletelyConcrete::TangibleThings::TargetsOneAction\", dependent: :destroy, foreign_key: :tangible_thing_id, enable_updates: true, inverse_of: :tangible_thing",
      HAS_MANY_HOOK,
      prepend: true
    )

    # Update the ability file
    add_line_to_file("app/models/ability.rb", transform_string("Scaffolding::CompletelyConcrete::TangibleThings::TargetsOneAction,"), "# 🚅 add action models above.", prepend: true)

    # Add the concern we have to add manually because otherwise it gets transformed.
    add_line_to_file(transform_string("app/models/scaffolding/completely_concrete/tangible_things/targets_one_action.rb"), "include Actions::TargetsOne", "include Actions::SupportsScheduling", prepend: true)

    # Restart the server to pick up the translation files
    restart_server

    # Update the routes to add the namespace and action routes
    routes_manipulator = Scaffolding::RoutesFileManipulator.new("config/routes.rb", transform_string("Scaffolding::CompletelyConcrete::TangibleThings::TargetsOneAction"), transform_string("Scaffolding::CompletelyConcrete::TangibleThing"))
    routes_manipulator.apply(["account"])
    # TODO We need this to also add `post :approve` to the resource block as well. Do we support that already?
    routes_manipulator.write

    add_additional_step :yellow, "We've generated a new model and migration file for you, so make sure to run `rake db:migrate`."

    additional_steps.each_with_index do |additional_step, index|
      color, message = additional_step
      puts ""
      puts "#{index + 1}. #{message}".send(color)
    end
    puts ""
  end

  def transform_string(string)
    string = super(string)

    [
      "Targets One to",
      "append an emoji to",
      "TargetsOne",
      "targets_one",
      "Targets One",
    ].each do |needle|
      # TODO There might be more to do here?
      # What method is this calling?
      string = string.gsub(needle, encode_double_replacement_fix(replacement_for(needle)))
    end
    decode_double_replacement_fix(string)
  end

  def replacement_for(string)
    case string
    # Some weird edge cases we unwittingly introduced in the emoji example.
    when "Targets One to"
      # e.g. "Archive"
      # If someone wants language like "Targets One to", they have to add it manually or name their model that.
      action.titlecase
    when "append an emoji to"
      # e.g. "archive"
      # If someone wants language like "append an emoji to", they have to add it manually.
      action.humanize
    when "TargetsOne"
      action
    when "targets_one"
      action.underscore
    when "Targets One"
      action.titlecase
    else
      "🛑"
    end
  end

  #
  # This method adds the hooks to the parent model class if they don't already exist
  # This could happen if someone scaffolds some initial models using the base version of Bullet Train, then they
  # upgrade to the action_models extension.  If that happens, we need to add the action_model hooks in manually.
  #
  def add_parent_model_action_model_hooks
    index_file = transform_string "./app/views/account/scaffolding/completely_concrete/tangible_things/_index.html.erb"
    return if File.read(index_file).include?("<%= action_model_select_controller do %>")
    block_manipulator = Scaffolding::BlockManipulator.new(index_file)
    block_manipulator.insert("<%# 🚅 super scaffolding will insert new action model buttons above this line. %>", after_block: transform_string("<% if can? :destroy, tangible_thing"))
    block_manipulator.write
  end
end
