import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';

/// Cropin Grow header: menu, search box with green search button (plus the
/// voice mic), QR scanner and notification bell.
class CropinTopBar extends StatelessWidget implements PreferredSizeWidget {
  const CropinTopBar({
    super.key,
    required this.hint,
    required this.onMic,
    this.controller,
    this.onSubmitted,
    this.onBell,
  });

  final String hint;
  final VoidCallback onMic;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onBell;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CropinColors.header,
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 25),
              onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
            ),
            Expanded(
              child: Container(
                height: 39,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: const TextStyle(color: CropinColors.hint, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.only(left: 14, top: 12, bottom: 12),
                      ),
                    ),
                  ),
                  InkResponse(
                    key: const Key('topbar-mic'),
                    onTap: onMic,
                    radius: 18,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.mic, color: CropinColors.primary, size: 21),
                    ),
                  ),
                  InkWell(
                    onTap: () => onSubmitted?.call(controller?.text ?? ''),
                    child: Container(
                      width: 44,
                      height: 39,
                      decoration: const BoxDecoration(
                        color: CropinColors.green,
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                      child: const Icon(Icons.search, color: Colors.white, size: 25),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 25),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR scanner is not part of this voice demo'))),
            ),
            ListenableBuilder(
              listenable: AppStore.instance,
              builder: (context, _) {
                final n = AppStore.instance.alerts.where((a) => a.byVoice).length;
                return IconButton(
                  onPressed: onBell,
                  icon: Badge(
                    isLabelVisible: n > 0,
                    label: Text('$n'),
                    backgroundColor: CropinColors.attention,
                    child: const Icon(Icons.notifications_none, color: Colors.white, size: 26),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

/// Title app bar used on Add Farmer / Add Asset / Raise alert screens.
PreferredSizeWidget cropinTitleBar(BuildContext context, String title, {List<Widget>? actions}) =>
    AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 23),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: actions,
    );
