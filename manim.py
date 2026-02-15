from manim import *

class GenScene(Scene):
    def construct(self):
        circle = Circle(radius=2).set_color(RED)
        square = Square(side_length=2).set_color(GREEN)

        self.add(circle, square)
        
        self.play(ApplyMethod(circle.scale, 0.5), ApplyMethod(square.scale, 0.5))
        self.wait()
        
        self.play(Transform(circle, square), run_time=3)