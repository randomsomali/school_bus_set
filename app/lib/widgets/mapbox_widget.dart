import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxWidget extends StatefulWidget {
  final double lat;
  final double lng;
  final String? address;
  final String? description;

  const MapboxWidget({
    super.key,
    required this.lat,
    required this.lng,
    this.address,
    this.description,
  });

  @override
  State<MapboxWidget> createState() => _MapboxWidgetState();
}

class _MapboxWidgetState extends State<MapboxWidget>
    with SingleTickerProviderStateMixin {
  MapboxMap? mapboxMap;
  CircleAnnotationManager? circleAnnotationManager;
  PointAnnotationManager? pointAnnotationManager;
  bool _mapInitialized = false;
  String? _errorMessage;
  String _currentStyle = 'streets';
  late AnimationController _animationController;

  // Map style options
  final Map<String, String> _mapStyles = {
    'streets': MapboxStyles.MAPBOX_STREETS,
    'satellite': MapboxStyles.SATELLITE,
    'satelliteStreets': MapboxStyles.SATELLITE_STREETS,
    'outdoors': MapboxStyles.OUTDOORS,
    'light': MapboxStyles.LIGHT,
    'dark': MapboxStyles.DARK,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    mapboxMap?.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    setState(() {
      _mapInitialized = true;
    });

    // Initialize annotation manager and add marker
    mapboxMap.annotations.createCircleAnnotationManager().then((manager) {
      circleAnnotationManager = manager;
      _addCircleMarker();
    }).catchError((error) {
      setState(() {
        _errorMessage = "Failed to create annotation manager: $error";
      });
      print("Annotation manager error: $error");
    });

    // Create point annotation manager for text labels
    mapboxMap.annotations.createPointAnnotationManager().then((manager) {
      pointAnnotationManager = manager;
      if (widget.address != null) {
        _addAddressLabel();
      }
    }).catchError((error) {
      print("Point annotation error: $error");
    });

    // Set initial camera position
    try {
      mapboxMap.setCamera(
        CameraOptions(
          center: Point.fromJson({
            "coordinates": [widget.lng, widget.lat]
          }),
          zoom: 14,
          bearing: 0,
          pitch: 0,
        ),
      );

      // Enable gesture handling with simplified settings
      mapboxMap.gestures.updateSettings(
        GesturesSettings(
          rotateEnabled: true,
          pitchEnabled: true,
          scrollEnabled: true,
          simultaneousRotateAndPinchToZoomEnabled: true,
          doubleTapToZoomInEnabled: true,
          doubleTouchToZoomOutEnabled: true,
          quickZoomEnabled: true,
          pinchToZoomEnabled: true,
          scrollMode: ScrollMode.HORIZONTAL_AND_VERTICAL,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Camera setup error: $e";
      });
      print("Camera setup error: $e");
    }
  }

  void _addCircleMarker() {
    try {
      // Create a circle annotation
      final options = CircleAnnotationOptions(
        geometry: Point.fromJson({
          "coordinates": [widget.lng, widget.lat]
        }),
        circleRadius: 8.0,
        circleColor: Colors.red.value,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      );

      circleAnnotationManager?.create(options);
    } catch (e) {
      setState(() {
        _errorMessage = "Marker creation error: $e";
      });
      print("Marker creation error: $e");
    }
  }

  void _addAddressLabel() {
    try {
      if (pointAnnotationManager != null && widget.address != null) {
        final textOptions = PointAnnotationOptions(
          geometry: Point.fromJson({
            "coordinates": [widget.lng, widget.lat]
          }),
          textField: widget.address,
          textOffset: [0, 2], // Offset the text above the point
          textColor: Colors.black.value,
          textSize: 12,
          textHaloColor: Colors.white.value,
          textHaloWidth: 1.0,
        );
        pointAnnotationManager!.create(textOptions);
      }
    } catch (e) {
      print("Address label creation error: $e");
    }
  }

  void _changeMapStyle(String style) {
    if (_mapStyles.containsKey(style)) {
      setState(() {
        _currentStyle = style;
        _mapInitialized = false;
      });
    }
  }

  String _getStyleDisplayName(String style) {
    final styleNames = {
      'streets': 'Streets',
      'satellite': 'Satellite',
      'satelliteStreets': 'Satellite Streets',
      'outdoors': 'Outdoors',
      'light': 'Light',
      'dark': 'Dark'
    };
    return styleNames[style] ?? style;
  }

  void _centerMap() {
    if (mapboxMap != null) {
      _animationController.forward(from: 0.0);
      mapboxMap?.setCamera(
        CameraOptions(
          center: Point.fromJson({
            "coordinates": [widget.lng, widget.lat]
          }),
          zoom: 14,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Error message display
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Map Error: $_errorMessage",
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            // Loading indicator
            if (!_mapInitialized && _errorMessage == null)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text("Loading map..."),
                  ],
                ),
              ),

            // Map widget
            MapWidget(
              key: ValueKey(_currentStyle),
              styleUri: _mapStyles[_currentStyle]!,
              onMapCreated: _onMapCreated,
              cameraOptions: CameraOptions(
                center: Point.fromJson({
                  "coordinates": [widget.lng, widget.lat]
                }),
                zoom: 14,
              ),
              mapOptions: MapOptions(
                contextMode: ContextMode.UNIQUE,
                constrainMode: ConstrainMode.NONE,
                orientation: NorthOrientation.UPWARDS,
                crossSourceCollisions: true,
                size: Size(
                  width: MediaQuery.of(context).size.width,
                  height: 500,
                ),
                pixelRatio: MediaQuery.of(context).devicePixelRatio,
              ),
            ),

            // Map style selector
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _currentStyle,
                  underline: const SizedBox(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  items: _mapStyles.keys.map((String style) {
                    return DropdownMenuItem<String>(
                      value: style,
                      child: Text(_getStyleDisplayName(style)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _changeMapStyle(newValue);
                    }
                  },
                ),
              ),
            ),

            // Center button
            Positioned(
              bottom: 16,
              right: 16,
              child: ScaleTransition(
                scale: Tween(begin: 1.0, end: 0.8).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: FloatingActionButton.small(
                  onPressed: _centerMap,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
