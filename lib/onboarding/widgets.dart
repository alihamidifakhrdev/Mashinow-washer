import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';

/// انتخابگر عکس — کاشی گرد گوشه با پیش‌نمایش (سبک سایت)
class ImagePickerTile extends StatelessWidget {
  final String label;
  final bool required_;
  final File? picked;
  final ValueChanged<File?> onChanged;

  const ImagePickerTile({
    super.key,
    required this.label,
    this.required_ = false,
    required this.picked,
    required this.onChanged,
  });

  Future<void> _pick() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 82,
    );

    if (file != null) {
      onChanged(File(file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  label + (required_ ? '' : ' (اختیاری)'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink2,
                  ),
                ),
              ),
              if (required_)
                Text(' *', style: TextStyle(color: AppColors.red)),
            ],
          ),
        ),
        InkWell(
          onTap: _pick,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.fill,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: picked == null
                  ? Border.all(color: AppColors.fill2, width: 1.4)
                  : null,
            ),
            child: picked == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.add_a_photo_outlined,
                          size: 22, color: AppColors.ink3),
                      const SizedBox(width: 10),
                      Text(
                        'انتخاب عکس (حداکثر ۱ مگابایت)',
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink2,
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.file(picked!, fit: BoxFit.cover),
                        PositionedDirectional(
                          top: 6,
                          end: 6,
                          child: GestureDetector(
                            onTap: () => onChanged(null),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
