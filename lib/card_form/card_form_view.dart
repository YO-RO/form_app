import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'input_formatter.dart';
import 'validator.dart';

class CardFormView extends HookConsumerWidget {
  const CardFormView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pressedSubmit = useState(false);

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final cardNumberController = useTextEditingController(text: '');
    final nameController = useTextEditingController(text: '');
    final dateTextController = useTextEditingController(text: '');
    final cvcNumberController = useTextEditingController(text: '');

    void resetForm() {
      pressedSubmit.value = false;

      // [TextFormField.initialValue]はリビルド時に[TextEditingController.text]
      // で上書きされる（[TextFormField]のソースより）。そのため、期待通りにリセットされない。
      formKey.currentState!.reset();
      cardNumberController.clear();
      nameController.clear();
      dateTextController.clear();
      cvcNumberController.clear();
    }

    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaleFactor: textScaleFactor.clamp(0, 2)),
      child: Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            TextFormField(
              controller: cardNumberController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              enableIMEPersonalizedLearning: false,
              autocorrect: false,
              inputFormatters: [
                HalfWidthFormatter(),
                CardNumberInputFormatter(const [4, 4, 4, 4]),
              ],
              validator: (text) => validateCardNumber(text ?? ''),
              autovalidateMode:
                  pressedSubmit.value ? AutovalidateMode.always : null,
              decoration: const InputDecoration(
                labelText: 'カード番号',
                hintText: '1234 1234 1234 1234',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '名義人',
                hintText: 'Taro Yamada',
                border: OutlineInputBorder(),
              ),
              validator: (text) => validateName(text ?? ''),
              autovalidateMode:
                  pressedSubmit.value ? AutovalidateMode.always : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Flexible(
                  child: TextFormField(
                    controller: dateTextController,
                    keyboardType:
                        const TextInputType.numberWithOptions(signed: true),
                    textInputAction: TextInputAction.next,
                    enableIMEPersonalizedLearning: false,
                    autocorrect: false,
                    inputFormatters: [
                      HalfWidthFormatter(),
                      DateInputFormatter(),
                    ],
                    validator: (text) =>
                        validateDate(text ?? '', DateTime.now()),
                    autovalidateMode:
                        pressedSubmit.value ? AutovalidateMode.always : null,
                    decoration: const InputDecoration(
                      labelText: '有効期限',
                      hintText: 'MM / YY',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: TextFormField(
                    controller: cvcNumberController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableIMEPersonalizedLearning: false,
                    inputFormatters: [
                      HalfWidthFormatter(),
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (text) => validateCVC(text ?? ''),
                    autovalidateMode:
                        pressedSubmit.value ? AutovalidateMode.always : null,
                    decoration: const InputDecoration(
                      labelText: 'CVC',
                      hintText: '123',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  pressedSubmit.value = true;
                  if (!formKey.currentState!.validate()) return;

                  // final cardNumber = int.parse(cardNumberController.text);
                  resetForm();
                },
                child: const Text(
                  '登録する',
                  softWrap: false,
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
