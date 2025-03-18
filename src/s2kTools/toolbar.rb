module Plugins::S2kTools
  def self.create_toolbar
    toolbar = UI::Toolbar.new "S2kTools"
    icon_dir = File.join(File.dirname(__FILE__), "images").gsub("\\", "/")

    cmd_move_model = UI::Command.new("Snap model to origin") {
      Plugins::S2kTools.move_model_to_origin
    }
    cmd_move_model.small_icon = File.join(icon_dir, "move_model_22.png")
    cmd_move_model.large_icon = File.join(icon_dir, "move_model_32.png")
    cmd_move_model.tooltip = "Snap model to origin"
    toolbar.add_item cmd_move_model

    cmd_export_model = UI::Command.new("Export View to PDF") {
      Plugins::S2kTools.export_view_to_pdf
    }
    cmd_export_model.small_icon = File.join(icon_dir, "export_model_22.png")
    cmd_export_model.large_icon = File.join(icon_dir, "export_model_32.png")
    cmd_export_model.tooltip = "Export Model to PDF"
    toolbar.add_item cmd_export_model

    cmd_configure = UI::Command.new("Configure S2kTools") {
      Plugins::S2kTools.configure_extension
    }
    cmd_configure.small_icon = File.join(icon_dir, "configure_22.png")
    cmd_configure.large_icon = File.join(icon_dir, "configure_32.png")
    cmd_configure.tooltip = "Configure S2kTools"
    toolbar.add_item cmd_configure

    cmd_fix_axes = UI::Command.new("Fix Group Axes") {
    Plugins::S2kTools::CustomGroupFixer.fix_selected_group
    }
    cmd_fix_axes.small_icon = File.join(icon_dir, "fix_axes_22.png")
    cmd_fix_axes.large_icon = File.join(icon_dir, "fix_axes_32.png")
    cmd_fix_axes.tooltip = "Fix Axes"
    toolbar.add_item cmd_fix_axes

    toolbar.show
  end
end
