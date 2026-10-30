"""Editable compositor with packed originals, not a reconstructed 3D model."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=1
bpy.ops.object.camera_add(location=(0,0,5))
scene.camera=bpy.context.object
scene.render.resolution_x=1254
scene.render.resolution_y=1254
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=True
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
tree=bpy.data.node_groups.new('Fronda | original + matte','CompositorNodeTree')
tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
scene.compositing_node_group=tree
original=tree.nodes.new('CompositorNodeImage')
original.label='ARTE APROVADA — manter pixels e cor'
original.location=(-550,160)
original.image=bpy.data.images.load(str(ROOT/'source/approved-icon.png'))
original.image.pack()
matte=tree.nodes.new('CompositorNodeImage')
matte.label='MÁSCARA — apenas transparência externa'
matte.location=(-550,-140)
matte.image=bpy.data.images.load(str(ROOT/'source/final-matte.png'))
matte.image.colorspace_settings.name='Non-Color'
matte.image.pack()
alpha=tree.nodes.new('CompositorNodeSetAlpha')
alpha.inputs['Type'].default_value='Replace Alpha'
alpha.location=(-180,160)
output=tree.nodes.new('NodeGroupOutput')
output.location=(100,160)
tree.links.new(original.outputs['Image'],alpha.inputs['Image'])
tree.links.new(matte.outputs['Image'],alpha.inputs['Alpha'])
tree.links.new(alpha.outputs['Image'],output.inputs['Image'])
scene['Fronda']='Composição 2D fiel. Original e máscara incorporados. Não é malha 3D.'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.type='NODE_EDITOR'
            area.ui_type='CompositorNodeTree'
scene.render.filepath=str(ROOT/'qa/blender-compositor.png')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/Fronda-Compositing.blend'))
bpy.ops.render.render(write_still=True)
