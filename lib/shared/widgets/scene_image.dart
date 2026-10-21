import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Which picture to show and how to frame it: [zoom] > 1 zooms in toward
/// [focus] (x/y from -1 = left/top to 1 = right/bottom).
@immutable
class SceneFrame {
  const SceneFrame(this.asset, {this.focus = Alignment.center, this.zoom = 1});

  /// A bundled asset path, or an http(s) URL for pictures from the story server.
  final String asset;
  final Alignment focus;
  final double zoom;

  ImageProvider get provider => imageProviderFor(asset);
}

/// Bundled pictures load from the app; server pictures load over the network.
ImageProvider imageProviderFor(String path) =>
    path.startsWith('http://') || path.startsWith('https://')
        ? NetworkImage(path) as ImageProvider
        : AssetImage(path);

/// Rounded illustration that fills its parent. Used for the main scene,
/// the thumbnails and the library covers.
class SceneImage extends StatelessWidget {
  const SceneImage({
    super.key,
    required this.frame,
    this.radius = AppDimens.radiusL,
    this.semanticLabel,
  });

  final SceneFrame frame;
  final double radius;

  /// Leave null for decorative images (the text already tells the story).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget image = Image(
      image: frame.provider,
      fit: BoxFit.cover,
      alignment: frame.focus,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.image_outlined, color: AppColors.inkSoft),
      ),
    );
    if (frame.zoom != 1) {
      image = Transform.scale(scale: frame.zoom, alignment: frame.focus, child: image);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(color: AppColors.tint, child: image),
    );
  }
}
