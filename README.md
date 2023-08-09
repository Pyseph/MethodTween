# MethodTween
Allows for smooth interpolation for object methods in Roblox.

MethodTween allows you to animate non-tweenable properties such as Scale & CFrames of models, through an API that aims to replicate Roblox's by as much as possible. The implementation includes support for reversing, delays, repeats & different tweening styles and directions.
Due to the getter & setter methods being separate & using separate namings (e.g., `GetPivot()` and `PivotTo`, or `GetScale` & `ScaleTo`), each field accepts an array of two values; the start and end value to tween to-and-fro.
