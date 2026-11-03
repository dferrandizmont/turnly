import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router.dart';
import '../../settings/presentation/settings_widgets.dart';
import '../application/share_link_controller.dart';
import 'share_link_icons.dart';

/// The «Compartir por enlace» row of Ajustes, opening `/ajustes/compartir`.
/// Says «Enlace publicado» while there is a live link.
class ShareLinkSettingsRow extends ConsumerWidget {
  const ShareLinkSettingsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final published = ref.watch(
      shareLinkControllerProvider.select((s) => s.available && s.isPublished),
    );
    return SettingsRow(
      key: const ValueKey('settings-share-link'),
      icon: ShareLinkIcons.link,
      title: l10n.shareLinkRowTitle,
      subtitle: published
          ? l10n.shareLinkRowPublished
          : l10n.shareLinkRowSubtitle,
      onTap: () => context.push(AppRoutes.settingsShareLink),
    );
  }
}
