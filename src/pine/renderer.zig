const Plugin = @import("pecs").Plugin;

const RendererPlugin = Plugin.init("renderer", struct {
    pub fn init() void {}
}.init);
