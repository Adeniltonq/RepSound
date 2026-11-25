import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_tab.dart';
import '../../state/settings_controller.dart';
import '../widgets/app_snack.dart';

/// Personaliza a barra inferior: ordem das abas e aba inicial.
class CustomizeBarScreen extends StatelessWidget {
  const CustomizeBarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = context.watch<SettingsController>();
    final order = settings.tabOrder;

    return Scaffold(
      appBar: AppBar(title: const Text('Barra inferior')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: Text(
              'Arraste para reordenar as abas. O conteúdo de cada aba não muda.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              buildDefaultDragHandles: false,
              itemCount: order.length,
              onReorderItem: (oldIndex, newIndex) {
                final next = List<AppTab>.of(order);
                final tab = next.removeAt(oldIndex);
                next.insert(newIndex, tab);
                settings.setTabOrder(next);
              },
              itemBuilder: (context, index) {
                final tab = order[index];
                final isInitial = tab == settings.initialTab;
                return Padding(
                  key: ValueKey<String>('tab_${tab.name}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: theme.brightness == Brightness.dark
                        ? scheme.surfaceContainerLow
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isInitial
                              ? scheme.primary.withValues(alpha: 0.5)
                              : scheme.outlineVariant,
                        ),
                      ),
                      leading: Icon(
                        isInitial ? tab.selectedIcon : tab.icon,
                        color: isInitial ? scheme.primary : null,
                      ),
                      title: Text(tab.label),
                      subtitle: Text(
                        isInitial
                            ? 'Aba inicial'
                            : 'Toque para definir como inicial',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isInitial
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            isInitial
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isInitial
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        settings.setInitialTab(tab);
                        showAppSnack(
                          context,
                          '${tab.label} será a aba inicial.',
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        settings.resetTabBar();
                        showAppSnack(context, 'Barra restaurada ao padrão.');
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Restaurar padrão'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
