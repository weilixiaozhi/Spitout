import 'package:flutter/material.dart';
import 'package:spitout/l10n/app_localizations.dart';
import 'package:spitout/theme/dimens.dart';

class AppEmpty extends StatelessWidget {
  final String? text;
  final String? subtext;
  const AppEmpty({super.key, this.text, this.subtext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpitoutDimens.p20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text ?? AppLocalizations.of(context).commonEmpty,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (subtext != null) ...[
              const SizedBox(height: SpitoutDimens.p4),
              Text(subtext!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
