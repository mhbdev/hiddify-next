import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/core_providers.dart';
import 'package:hiddify/domain/failures.dart';
import 'package:hiddify/features/common/confirmation_dialogs.dart';
import 'package:hiddify/features/profile_detail/notifier/notifier.dart';
import 'package:hiddify/features/settings/widgets/widgets.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:humanizer/humanizer.dart';

class ProfileDetailPage extends HookConsumerWidget with PresLogger {
  const ProfileDetailPage(this.id, {super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);

    final provider = profileDetailNotifierProvider(id);
    final notifier = ref.watch(provider.notifier);

    ref.listen(
      provider.select((data) => data.whenData((value) => value.save)),
      (_, asyncSave) {
        if (asyncSave case AsyncData(value: final save)) {
          switch (save) {
            case MutationFailure(:final failure):
              CustomAlertDialog.fromErr(t.presentError(failure)).show(context);
            case MutationSuccess():
              CustomToast.success(t.profile.save.successMsg).show(context);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) {
                  if (context.mounted) context.pop();
                },
              );
          }
        }
      },
    );

    ref.listen(
      provider.select((data) => data.whenData((value) => value.update)),
      (_, asyncUpdate) {
        if (asyncUpdate case AsyncData(value: final update)) {
          switch (update) {
            case MutationFailure(:final failure):
              CustomAlertDialog.fromErr(t.presentError(failure)).show(context);
            case MutationSuccess():
              CustomToast.success(t.profile.update.successMsg).show(context);
          }
        }
      },
    );

    ref.listen(
      provider.select((data) => data.whenData((value) => value.delete)),
      (_, asyncDelete) {
        if (asyncDelete case AsyncData(value: final delete)) {
          switch (delete) {
            case MutationFailure(:final failure):
              CustomToast.error(t.printError(failure)).show(context);
            case MutationSuccess():
              CustomToast.success(t.profile.delete.successMsg).show(context);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) {
                  if (context.mounted) context.pop();
                },
              );
          }
        }
      },
    );

    switch (ref.watch(provider)) {
      case AsyncData(value: final state):
        final showLoadingOverlay = state.isBusy ||
            state.save is MutationSuccess ||
            state.delete is MutationSuccess;

        return Stack(
          children: [
            Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: Text(t.profile.detailsPageTitle),
                    pinned: true,
                    actions: [
                      if (state.isEditing)
                        PopupMenuButton(
                          itemBuilder: (context) {
                            return [
                              PopupMenuItem(
                                child: Text(t.profile.update.buttonTxt),
                                onTap: () async {
                                  await notifier.updateProfile();
                                },
                              ),
                              PopupMenuItem(
                                child: Text(t.profile.delete.buttonTxt),
                                onTap: () async {
                                  final deleteConfirmed =
                                      await showConfirmationDialog(
                                    context,
                                    title: t.profile.delete.buttonTxt,
                                    message: t.profile.delete.confirmationMsg,
                                  );
                                  if (deleteConfirmed) {
                                    await notifier.delete();
                                  }
                                },
                              ),
                            ];
                          },
                        ),
                    ],
                  ),
                  Form(
                    autovalidateMode: state.showErrorMessages
                        ? AutovalidateMode.always
                        : AutovalidateMode.disabled,
                    child: SliverList.list(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: CustomTextFormField(
                            initialValue: state.profile.name,
                            onChanged: (value) =>
                                notifier.setField(name: value),
                            validator: (value) => (value?.isEmpty ?? true)
                                ? t.profile.detailsForm.emptyNameMsg
                                : null,
                            label: t.profile.detailsForm.nameLabel,
                            hint: t.profile.detailsForm.nameHint,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: CustomTextFormField(
                            initialValue: state.profile.url,
                            onChanged: (value) => notifier.setField(url: value),
                            validator: (value) =>
                                (value != null && !isUrl(value))
                                    ? t.profile.detailsForm.invalidUrlMsg
                                    : null,
                            label: t.profile.detailsForm.urlLabel,
                            hint: t.profile.detailsForm.urlHint,
                          ),
                        ),
                        ListTile(
                          title: Text(t.profile.detailsForm.updateInterval),
                          subtitle: Text(
                            state.profile.options?.updateInterval
                                    .toApproximateTime(
                                  isRelativeToNow: false,
                                ) ??
                                t.general.toggle.disabled,
                          ),
                          leading: const Icon(Icons.update),
                          onTap: () async {
                            final intervalInHours = await SettingsInputDialog(
                              title: t.profile.detailsForm
                                  .updateIntervalDialogTitle,
                              initialValue:
                                  state.profile.options?.updateInterval.inHours,
                              optionalAction: (
                                t.general.state.disable,
                                () => notifier.setField(updateInterval: none()),
                              ),
                              validator: isPort,
                              mapTo: int.tryParse,
                              digitsOnly: true,
                            ).show(context);
                            if (intervalInHours == null) return;
                            notifier.setField(
                              updateInterval: optionOf(intervalInHours),
                            );
                          },
                        ),
                        if (state.isEditing)
                          ListTile(
                            title: Text(t.profile.detailsForm.lastUpdate),
                            subtitle: Text(state.profile.lastUpdate.format()),
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          OverflowBar(
                            spacing: 12,
                            overflowAlignment: OverflowBarAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: context.pop,
                                child: Text(
                                  MaterialLocalizations.of(context)
                                      .cancelButtonLabel,
                                ),
                              ),
                              FilledButton(
                                onPressed: notifier.save,
                                child: Text(t.profile.save.buttonText),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showLoadingOverlay)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LinearProgressIndicator(
                        backgroundColor: Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );

      case AsyncError(:final error):
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(t.profile.detailsPageTitle),
                pinned: true,
              ),
              SliverErrorBodyPlaceholder(t.printError(error)),
            ],
          ),
        );

      default:
        return const Scaffold();
    }
  }
}
