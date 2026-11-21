import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Vision simulation filters allowing creators to preview their verse card
/// for color-vision deficiency (CVD) and low-vision readability before sharing.
enum VisionSimulationMode {
  normal,
  protanopia,
  deuteranopia,
  tritanopia,
  grayscale,
  lowVisionBlur;

  String get localeKey {
    switch (this) {
      case VisionSimulationMode.normal:
        return 'vision_sim_normal';
      case VisionSimulationMode.protanopia:
        return 'vision_sim_protanopia';
      case VisionSimulationMode.deuteranopia:
        return 'vision_sim_deuteranopia';
      case VisionSimulationMode.tritanopia:
        return 'vision_sim_tritanopia';
      case VisionSimulationMode.grayscale:
        return 'vision_sim_grayscale';
      case VisionSimulationMode.lowVisionBlur:
        return 'vision_sim_low_vision';
    }
  }

  /// Standard 4x5 color transformation matrix for CVD / grayscale simulation,
  /// or `null` when no color matrix applies.
  List<double>? get colorMatrix {
    switch (this) {
      case VisionSimulationMode.normal:
      case VisionSimulationMode.lowVisionBlur:
        return null;
      case VisionSimulationMode.protanopia:
        return const <double>[
          0.567, 0.433, 0.000, 0, 0,
          0.558, 0.442, 0.000, 0, 0,
          0.000, 0.242, 0.758, 0, 0,
          0.000, 0.000, 0.000, 1, 0,
        ];
      case VisionSimulationMode.deuteranopia:
        return const <double>[
          0.625, 0.375, 0.000, 0, 0,
          0.700, 0.300, 0.000, 0, 0,
          0.000, 0.300, 0.700, 0, 0,
          0.000, 0.000, 0.000, 1, 0,
        ];
      case VisionSimulationMode.tritanopia:
        return const <double>[
          0.950, 0.050, 0.000, 0, 0,
          0.000, 0.433, 0.567, 0, 0,
          0.000, 0.475, 0.525, 0, 0,
          0.000, 0.000, 0.000, 1, 0,
        ];
      case VisionSimulationMode.grayscale:
        return const <double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.0000, 0.0000, 0.0000, 1, 0,
        ];
    }
  }
}

/// Applies the selected [VisionSimulationMode] non-destructively to [child].
class VisionSimulatorFilter extends StatelessWidget {
  final VisionSimulationMode mode;
  final Widget child;

  const VisionSimulatorFilter({
    super.key,
    required this.mode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == VisionSimulationMode.normal) {
      return child;
    }
    if (mode == VisionSimulationMode.lowVisionBlur) {
      return ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
        child: child,
      );
    }
    final List<double>? matrix = mode.colorMatrix;
    if (matrix == null) return child;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: child,
    );
  }
}
