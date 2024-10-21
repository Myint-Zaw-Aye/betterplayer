import 'package:flutter/material.dart';

class NormalPlayerPage extends StatefulWidget {
  @override
  _NormalPlayerPageState createState() => _NormalPlayerPageState();
}

class _NormalPlayerPageState extends State<NormalPlayerPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: HitAreaVideo()
    );
  }
}


class HitAreaVideo extends StatefulWidget {

  @override
  State<HitAreaVideo> createState() => _HitAreaVideoState();
}

class _HitAreaVideoState extends State<HitAreaVideo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool isLongPress= false;
   int activePointers = 0;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(isLongPress);
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        setState(() {
          isLongPress = true;
          activePointers++;
          print("plus");
        });
      },
      onPointerUp: (PointerUpEvent event) {
        setState(() {
          isLongPress = false;
          activePointers--;
          print('minus');
        });
      },
      child: GestureDetector(
       // behavior: HitTestBehavior.opaque,
        onVerticalDragDown:isLongPress?null:
        
         (details) {
            print(activePointers.toString()+ "this is active pointer");
            if (activePointers == 1) {
              isLongPress = false;
              print("Single finger vertical drag detected");
              // Handle single-finger drag logic here.
            }
          }
          ,
          onVerticalDragUpdate: isLongPress?null:
          
          (details) {
            if (activePointers == 1) {
              print("Dragging with one finger: ${details.primaryDelta}");
            }
          },
        onVerticalDragEnd: isLongPress?null:
        
         (dragEndDetails) {
           isLongPress = true;
        },
        child: InteractiveViewer(
            panEnabled: isLongPress,
            scaleEnabled: isLongPress,
          child: Center(child: Container(color: Colors.yellow,height: 200,))),
      ),
    );
  }
}



// import 'package:flutter/material.dart';

// class HitAreaVideo extends StatefulWidget {
//     final Widget videoWidget;
//   const HitAreaVideo({super.key, required this.videoWidget});

//   @override
//   State<HitAreaVideo> createState() => _HitAreaVideoState();
// }

// class _HitAreaVideoState extends State<HitAreaVideo>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   bool isLongPress= false;
//    int activePointers = 0;
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(vsync: this);
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     print(isLongPress);
//     return Listener(
//       onPointerDown: (PointerDownEvent event) {
//         setState(() {
//           isLongPress = true;
//           activePointers++;
//           print("plus");
//         });
//       },
//       onPointerUp: (PointerUpEvent event) {
//         setState(() {
//           isLongPress = false;
//           activePointers--;
//           print('minus');
//         });
//       },
//       child: GestureDetector(
//        // behavior: HitTestBehavior.opaque,
//         onVerticalDragDown:isLongPress?null:
        
//          (details) {
//             print(activePointers.toString()+ "this is active pointer");
//             if (activePointers == 1) {
//               isLongPress = false;
//               print("Single finger vertical drag detected");
//               // Handle single-finger drag logic here.
//             }
//           }
//           ,
//           onVerticalDragUpdate: isLongPress?null:
          
//           (details) {
//             if (activePointers == 1) {
//               print("Dragging with one finger: ${details.primaryDelta}");
//             }
//           },
//         onVerticalDragEnd: isLongPress?null:
        
//          (dragEndDetails) {
//            isLongPress = true;
//         },
//         child: InteractiveViewer(
//           panEnabled: isLongPress,
//           scaleEnabled: isLongPress,
//           child: widget.videoWidget
//           //Center(child: Container(color: Colors.yellow,height: 200,))
//           ),
//       ),
//     );
//   }
// }
