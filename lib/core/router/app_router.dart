import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/life_item/pages/life_item_list_page.dart';
import '../../features/life_item/pages/life_item_edit_page.dart';
import '../../features/bill/pages/bill_list_page.dart';
import '../../features/bill/pages/bill_edit_page.dart';
import '../../features/project/pages/project_list_page.dart';
import '../../features/project/pages/project_detail_page.dart';
import '../../features/project/pages/project_edit_page.dart';
import '../../features/project/pages/project_template_list_page.dart';
import '../../features/project/pages/project_template_edit_page.dart';
import '../../features/statistics/pages/statistics_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/settings/pages/category_management_page.dart';
import '../../features/settings/pages/data_safety_page.dart';
import '../../features/settings/pages/recycle_bin_page.dart';
import '../../features/search/search_page.dart';
import '../../features/smart_entry/models/draft_item.dart';
import '../../features/smart_entry/pages/smart_entry_confirm_page.dart';
import '../../features/smart_entry/pages/smart_entry_input_page.dart';
import '../../features/smart_entry/pages/ai_assistant_settings_page.dart';

int _currentIndex(GoRouterState state) {
  final path = state.uri.path;
  if (path.startsWith('/bills')) return 2;
  if (path.startsWith('/statistics')) return 3;
  if (path.startsWith('/settings')) return 4;
  if (path.startsWith('/items')) return 1;
  return 0;
}

void _onTap(BuildContext context, int index) {
  const routes = ['/home', '/items', '/bills', '/statistics', '/settings'];
  context.go(routes[index]);
}

Widget _buildShell(BuildContext context, GoRouterState state, Widget child) {
  return Scaffold(
    body: child,
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _currentIndex(state),
      onTap: (index) => _onTap(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: '首页',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.check_circle_outline),
          activeIcon: Icon(Icons.check_circle),
          label: '事项',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: '账单',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: '统计',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: '设置',
        ),
      ],
    ),
  );
}

final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    // 处理 lifeitems:// URI scheme（来自 App Shortcuts / Widget）。
    final uri = state.uri;
    if (uri.scheme == 'lifeitems') {
      // lifeitems://smart-entry/input → /smart-entry/input
      // lifeitems://bills/new → /bills/new
      // lifeitems://items → /items
      final path = '/${uri.host}${uri.path}';
      return path;
    }
    return null; // 不重定向
  },
  routes: [
    // Full-screen routes (no bottom navigation bar).
    GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
    GoRoute(
      path: '/smart-entry/input',
      builder: (context, state) => const SmartEntryInputPage(),
    ),
    GoRoute(
      path: '/smart-entry/confirm',
      builder: (context, state) {
        final draft = state.extra as EntryDraft;
        return SmartEntryConfirmPage(draft: draft);
      },
    ),
    ShellRoute(
      builder: _buildShell,
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/items',
          builder: (context, state) => const LifeItemListPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const LifeItemEditPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) => const LifeItemEditPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/bills',
          builder: (context, state) => const BillListPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const BillEditPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) => const BillEditPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/projects',
          builder: (context, state) => const ProjectListPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const ProjectEditPage(),
            ),
            GoRoute(
              path: 'templates',
              builder: (context, state) => const ProjectTemplateListPage(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const ProjectTemplateEditPage(),
                ),
                GoRoute(
                  path: ':id/edit',
                  builder: (context, state) => const ProjectTemplateEditPage(),
                ),
              ],
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => const ProjectDetailPage(),
            ),
            GoRoute(
              path: ':id/edit',
              builder: (context, state) => const ProjectEditPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/statistics',
          builder: (context, state) => const StatisticsPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
          routes: [
            GoRoute(
              path: 'categories',
              builder: (context, state) => const CategoryManagementPage(),
            ),
            GoRoute(
              path: 'data',
              builder: (context, state) => const DataSafetyPage(),
            ),
            GoRoute(
              path: 'recycle',
              builder: (context, state) => const RecycleBinPage(),
            ),
            GoRoute(
              path: 'ai-assistant',
              builder: (context, state) => const AiAssistantSettingsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
