- [ ] implement a terminal (ASCII) renderer and develop a small roguelike to test the capabilities of engine and the underlying ecs system.

- [ ] implement a scene graph for the actual renderer and render a cube.

- [ ] the window and render plugins' cleanup functions are disabled due to a use after free occuring because the window cleanup seemingly release the swapchain object. correct this so that resources can be properly cleaned up on program shutdown.
  - nb: figure out if the window cleanup is sufficiently cleaning up the rendering resources. if so, the rendering cleanup is redundant.
