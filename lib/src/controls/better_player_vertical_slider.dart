import 'package:flutter/material.dart';
class VerticalSlider extends StatefulWidget {
  final double min;
  final double max;
  final double? value;
  final ValueChanged<double> onChanged;

  VerticalSlider({
    required this.min,
    required this.max,
    this.value,
    required this.onChanged,
  });

  @override
  _VerticalSliderState createState() => _VerticalSliderState();
}

class _VerticalSliderState extends State<VerticalSlider> {
  late double _currentSliderValue;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
        _currentSliderValue = widget.value ?? widget.min;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Theme.of(context).primaryColor,
        trackHeight: 3.0,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: Slider(
          value: _currentSliderValue,
          min: widget.min,
          max: widget.max,
          onChanged: (value) {
            // setState(() {
            //   _currentSliderValue = value;
            // });
            // widget.onChanged(value);
          },
        ),
      ),
    );
  }
}

// class _CustomSliderThumbShape extends SliderComponentShape {
//   @override
//   Size getPreferredSize(bool isEnabled, bool isDiscrete) {
//     return Size(20, 40); // Customize the size of the thumb
//   }

//   @override
//   void paint(
//       PaintingContext context,
//       Offset center, {
//       Animation<double>? activationAnimation,
//       Animation<double>? enableAnimation,
//       bool? isDiscrete,
//       TextPainter? labelPainter,
//       RenderBox? parentBox,
//       SliderThemeData? sliderTheme,
//       TextDirection? textDirection,
//       double? value,
//       double? textScaleFactor,
//       Size? sizeWithOverflow,
//     }) {
//     final canvas = context.canvas;
//     final rect = Rect.fromCenter(
//       center: center,
//       width: 20, // Customize the width of the thumb
//       height: 40, // Customize the height of the thumb
//     );
//     final rrect = RRect.fromRectAndRadius(rect, Radius.circular(10));
//     final paint = Paint()..color = Colors.black;
//     canvas.drawRRect(rrect, paint);
//   }
// }
