import 'package:fluent_ui/fluent_ui.dart';
import '../../core/services/menu_service.dart';

void registerHelpMenu(BuildContext context) {
  final menuService = MenuService();

  menuService.registerMenu("Help", [
    MenuItemData(commandId: "help.packages"),
    MenuItemData(isSeparator: true),
    MenuItemData(commandId: "help.about"),
  ]);
}
