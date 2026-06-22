class DisplaySettings {
  final int width;
  final int height;
  final int scale;
  final String mode;
  final int rows;
  final String pathDirection;
  final String transitionType;
  final String? mascotImage;
  final String? topBannerImage;
  final int topBannerHeight;
  final String? bottomBannerImage;
  final int bottomBannerHeight;
  final bool showClock;
  final int autoPanTileHeight;
  final String selectedSprite;
  final String selectedSurface;
  final int roadHeight;
  final int autoPanRoadWidth;
  final bool autoOptimise;

  const DisplaySettings({
    this.width = 2560,
    this.height = 1080,
    this.scale = 100,
    this.mode = 'horizontal',
    this.rows = 1,
    this.pathDirection = 'sequential',
    this.transitionType = 'progress-line',
    this.mascotImage,
    this.topBannerImage,
    this.topBannerHeight = 48,
    this.bottomBannerImage,
    this.bottomBannerHeight = 48,
    this.showClock = false,
    this.autoPanTileHeight = 60,
    this.selectedSprite = 'penguin',
    this.selectedSurface = 'ice',
    this.roadHeight = 32,
    this.autoPanRoadWidth = 40,
    this.autoOptimise = false,
  });

  factory DisplaySettings.fromDbJson(Map<String, dynamic> json) {
    return DisplaySettings(
      width: json['width'] as int? ?? 2560,
      height: json['height'] as int? ?? 1080,
      scale: json['scale'] as int? ?? 100,
      mode: json['mode'] as String? ?? 'horizontal',
      rows: json['rows'] as int? ?? 1,
      pathDirection: json['path_direction'] as String? ?? 'sequential',
      transitionType: json['transition_type'] as String? ?? 'progress-line',
      mascotImage: json['mascot_image'] as String?,
      topBannerImage: json['top_banner_image'] as String?,
      topBannerHeight: json['top_banner_height'] as int? ?? 48,
      bottomBannerImage: json['bottom_banner_image'] as String?,
      bottomBannerHeight: json['bottom_banner_height'] as int? ?? 48,
      showClock: json['show_clock'] as bool? ?? false,
      autoPanTileHeight: json['auto_pan_tile_height'] as int? ?? 60,
      selectedSprite: json['selected_sprite'] as String? ?? 'penguin',
      selectedSurface: json['selected_surface'] as String? ?? 'ice',
      roadHeight: json['road_height'] as int? ?? 32,
      autoPanRoadWidth: json['auto_pan_road_width'] as int? ?? 40,
      autoOptimise: json['auto_optimise'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toDbJson() => {
        'width': width,
        'height': height,
        'scale': scale,
        'mode': mode,
        'rows': rows,
        'path_direction': pathDirection,
        'transition_type': transitionType,
        'mascot_image': mascotImage,
        'top_banner_image': topBannerImage,
        'top_banner_height': topBannerHeight,
        'bottom_banner_image': bottomBannerImage,
        'bottom_banner_height': bottomBannerHeight,
        'show_clock': showClock,
        'auto_pan_tile_height': autoPanTileHeight,
        'selected_sprite': selectedSprite,
        'selected_surface': selectedSurface,
        'road_height': roadHeight,
        'auto_pan_road_width': autoPanRoadWidth,
        'auto_optimise': autoOptimise,
      };

  /// DB keys that stay classroom-wide (live in `display_settings`, not on a
  /// template). Everything else follows the template.
  static const globalDbKeys = {'mode', 'transition_type', 'width', 'height'};

  /// Returns a copy with the classroom-wide fields taken from [global], keeping
  /// every per-template field from `this`. Used to resolve the settings the
  /// display actually renders: per-template values + the screen's globals.
  DisplaySettings withGlobalsFrom(DisplaySettings global) => copyWith(
        mode: global.mode,
        transitionType: global.transitionType,
        width: global.width,
        height: global.height,
      );

  /// Per-template subset of [toDbJson] — the classroom-wide keys removed. Stored
  /// in `templates.settings_json` and the `active_timeline` snapshot.
  Map<String, dynamic> toTemplateDbJson() {
    final json = toDbJson();
    for (final k in globalDbKeys) {
      json.remove(k);
    }
    return json;
  }

  DisplaySettings copyWith({
    int? width,
    int? height,
    int? scale,
    String? mode,
    int? rows,
    String? pathDirection,
    String? transitionType,
    String? mascotImage,
    String? topBannerImage,
    int? topBannerHeight,
    String? bottomBannerImage,
    int? bottomBannerHeight,
    bool? showClock,
    int? autoPanTileHeight,
    String? selectedSprite,
    String? selectedSurface,
    int? roadHeight,
    int? autoPanRoadWidth,
    bool? autoOptimise,
  }) {
    return DisplaySettings(
      width: width ?? this.width,
      height: height ?? this.height,
      scale: scale ?? this.scale,
      mode: mode ?? this.mode,
      rows: rows ?? this.rows,
      pathDirection: pathDirection ?? this.pathDirection,
      transitionType: transitionType ?? this.transitionType,
      mascotImage: mascotImage ?? this.mascotImage,
      topBannerImage: topBannerImage ?? this.topBannerImage,
      topBannerHeight: topBannerHeight ?? this.topBannerHeight,
      bottomBannerImage: bottomBannerImage ?? this.bottomBannerImage,
      bottomBannerHeight: bottomBannerHeight ?? this.bottomBannerHeight,
      showClock: showClock ?? this.showClock,
      autoPanTileHeight: autoPanTileHeight ?? this.autoPanTileHeight,
      selectedSprite: selectedSprite ?? this.selectedSprite,
      selectedSurface: selectedSurface ?? this.selectedSurface,
      roadHeight: roadHeight ?? this.roadHeight,
      autoPanRoadWidth: autoPanRoadWidth ?? this.autoPanRoadWidth,
      autoOptimise: autoOptimise ?? this.autoOptimise,
    );
  }
}
