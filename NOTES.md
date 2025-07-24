- [ ] the window event is currently pushed as a separate resource to a more general event type. merge this window event into such a structure (a Pine Event, if you will).

- [ ] implement a terminal (ASCII) renderer and develop a small roguelike to test the capabilities of engine and the underlying ecs system.

- [ ] implement a scene graph for the actual renderer and render a cube.

- [ ] the window and render plugins' cleanup functions are disabled due to a use after free occuring because the window cleanup seemingly release the swapchain object. correct this so that resources can be properly cleaned up on program shutdown.
  - nb: figure out if the window cleanup is sufficiently cleaning up the rendering resources. if so, the rendering cleanup is redundant.
