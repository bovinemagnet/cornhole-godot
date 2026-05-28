# Low-Poly Prop Pack

Reusable lightweight Godot prop scenes for the Corn Hole prototype:

- `PropCan.tscn`
- `PropBox.tscn`
- `PropBall.tscn`
- `PropBin.tscn`
- `PropBench.tscn`
- `PropCar.tscn`
- `PropTree.tscn`

Open `PropPackPreview.tscn` to inspect the pack together.

Each prop uses Godot primitive meshes and local materials only. The root node is a `Node3D` with a `VisualRoot` child and a `StaticBody3D` with a simple `CollisionShape3D`, so the scenes can be instanced as visuals now and adapted for gameplay metadata later.
