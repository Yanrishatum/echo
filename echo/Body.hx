package echo;

import hxmath.frames.Frame2;
import hxmath.math.Vector2;
import echo.util.Disposable;
import echo.util.Proxy;
import echo.Shape;
import echo.shape.Rect;
import echo.data.Data;
import echo.data.Options;

using echo.util.Ext;
/**
 * A `Body` is an Object representing a Physical Body in a `World`.
 *
 * Bodies have position, velocity, mass, an optional collider shape, and many other properties that are used in a `World` simulation.
 */
@:build(echo.Macros.build_body())
class Body implements IDisposable {
  /**
   * Default Body Options
   */
  public static var defaults(get, null):BodyOptions;

  static var ids:Int = 0;
  /**
   * Unique id of the Body.
   */
  public var id(default, null):Int;
  /**
   * The Body's position on the X axis.
   */
  public var x(get, set):Float;
  /**
   * The Body's position on the Y axis.
   */
  public var y(get, set):Float;
  /**
   * The Body's first `Shape` object in the `shapes` array. If it **isn't** null, this `Shape` object act as the Body's Collider, allowing it to be checked for Collisions.
   */
  public var shape(get, set):Null<Shape>;
  /**
   * The Body's array of `Shape` objects. If the array **isn't** empty, these `Shape` objects act as the Body's Collider, allowing it to be checked for Collisions.
   *
   * NOTE: If adding shapes directly to this Array, make sure to parent the Shape to the Body (ie `shape.set_parent(body.frame);`).
   */
  public var shapes(default, null):Array<Shape>;
  /**
   * TODO - Child Body transforms
   */
  @:dox(hide)
  private var children(default, null):Array<Body>;
  /**
   * Flag to set how a Body is affected by Collisions.
   *
   * If set to true, the Body will still Collide and move through the world, but it will not be moved by external collision forces.
   * This is useful for things like moving platforms.
   */
  public var kinematic:Bool;
  /**
   * Body's mass. Affects how the Body reacts to Collisions and Velocity.
   *
   * The higher a Body's mass, the more resistant it is to those forces.
   * If a Body's mass is set to `0`, it becomes static - unmovable by forces and collisions.
   */
  public var mass(default, set):Float;
  /**
   * Body's current rotational angle.
   */
  public var rotation(get, set):Float;
  /**
   * Value to determine how much of a Body's `velocity` should be retained during collisions (or how much should the `Body` "bounce" in other words).
   */
  public var elasticity:Float;
  /**
   * The units/second that a `Body` moves.
   */
  public var velocity:Vector2;
  /**
   * A measure of how fast a `Body` will change it's velocity. Can be thought of the sum of all external forces on an object (such as a World's gravity) during a step.
   */
  public var acceleration:Vector2;
  /**
   * The units/second that a `Body` will rotate.
   */
  public var rotational_velocity:Float;
  /**
   * The maximum velocity range that a `Body` can have.
   *
   * If set to 0, the Body has no restrictions on how fast it can move.
   */
  public var max_velocity:Vector2;
  /**
   * The maximum rotational velocity range that a `Body` can have. Currently not Implemented.
   *
   * If set to 0, the Body has no restrictions on how fast it can rotate.
   */
  public var max_rotational_velocity:Float;
  /**
   * A measure of how fast a Body will move its velocity towards 0 when there is no acceleration.
   */
  public var drag:Vector2;
  /**
   * Percentage value that represents how much a World's gravity affects the Body.
   */
  public var gravity_scale:Float;
  /**
   * Cached value of 1 divided by the Body's mass. Used in Internal calculations.
   */
  public var inverse_mass(default, null):Float;
  /**
   * Flag to set if the Body is active and will participate in a World's Physics calculations or Collision querys.
   */
  public var active:Bool;
  /**
   * TODO - sleeping support
   *
   * Flag to check if the Body is in a sleeping state. A Body is awake if it has any acceleration, velocity, or has changed its position/rotation since the last step.
   * If the Body's World has the `sleeping_bodies` optimization on, this flag determines if the Body will participate in a World's Physics calculations or Collision querys.
   */
  @:dox(hide)
  private var sleeping:Bool;
  /**
   * The `World` that this body is attached to. It can only be a part of one `World` at a time.
   */
  @:allow(echo.World)
  public var world(default, null):World;
  /**
   * Dynamic Object to store any user data on the `Body`. Useful for Callbacks.
   */
  public var data(default, null):Dynamic;
  /**
   * Flag to check if the Body collided with something during the step.
   * Used for debug drawing.
   */
  public var collided:Bool;
  /**
   * Structure to help perform matrix calculations for the Body's position and rotation.
   */
  public var frame(default, null):Frame2;
  /**
   * Flag to check if the Body has changed its position, rotation, or shape colliders.
   * Used for Collision optimization.
   */
  public var dirty:Bool;
  /**
   * If set, this method is called whenever the Body's X or Y changes.
   */
  public var on_move:Null<Float->Float->Void>;
  /**
   * If set, this method is called whenever the Body's rotation changes.
   */
  public var on_rotate:Null<Float->Void>;

  @:allow(echo.Physics.step)
  public var last_x(default, null):Float;
  @:allow(echo.Physics.step)
  public var last_y(default, null):Float;
  @:allow(echo.Physics.step)
  public var last_rotation(default, null):Float;

  @:dox(hide)
  @:allow(echo.World, echo.Collisions, echo.util.Debug)
  var quadtree_data:QuadTreeData;
  @:dox(hide)
  @:noCompletion
  var parent_frame:Frame2;
  /**
   * Creates a new Body.
   * @param options Optional values to configure the new Body
   */
  public function new(?options:BodyOptions) {
    this.id = ++ids;
    active = true;
    shapes = [];
    // TODO - Child Body transforms
    // children = [];
    frame = new Frame2(new Vector2(0, 0), 0);
    velocity = new Vector2(0, 0);
    acceleration = new Vector2(0, 0);
    max_velocity = new Vector2(0, 0);
    drag = new Vector2(0, 0);
    data = {};
    load_options(options);
  }
  /**
   * Sets a Body's values from a `BodyOptions` object.
   * @param options
   */
  public function load_options(?options:BodyOptions) {
    options = echo.util.JSON.copy_fields(options, defaults);
    clear_shapes();
    x = options.x;
    y = options.y;
    rotation = options.rotation;
    kinematic = options.kinematic;
    mass = options.mass;
    elasticity = options.elasticity;
    velocity.set(options.velocity_x, options.velocity_y);
    rotational_velocity = options.rotational_velocity;
    max_velocity.set(options.max_velocity_x, options.max_velocity_y);
    max_rotational_velocity = options.max_rotational_velocity;
    drag.set(options.drag_x, options.drag_y);
    gravity_scale = options.gravity_scale;
    last_x = Math.NaN;
    last_y = Math.NaN;
    last_rotation = Math.NaN;
    dirty = true;
    if (options.shape != null) create_shape(options.shape);
    if (options.shapes != null) for (shape in options.shapes) create_shape(shape);
  }

  public function clone():Body {
    var b = new Body();
    b.x = x;
    b.y = y;
    b.rotation = rotation;
    b.kinematic = kinematic;
    b.mass = mass;
    b.elasticity = elasticity;
    b.velocity.set(velocity.x, velocity.y);
    b.rotational_velocity = rotational_velocity;
    b.max_velocity.set(max_velocity.x, max_velocity.y);
    b.max_rotational_velocity = max_rotational_velocity;
    b.drag.set(drag.x, drag.y);
    b.gravity_scale = gravity_scale;
    b.last_x = last_x;
    b.last_y = last_y;
    b.last_rotation = last_rotation;
    b.shapes = shapes.map(s -> {
      var sc = s.clone();
      sc.set_parent(b.frame);
      return sc;
    });

    return b;
  }
  /**
   * TODO - Child Body transforms
   */
  @:dox(hide)
  @:noCompletion
  private inline function sync() {
    // TODO - add "Local" x, y, and rot
  }
  /**
   * TODO - Child Body transforms
   */
  @:dox(hide)
  @:noCompletion
  private inline function add_child(child:Body) {
    if (children.indexOf(child) == -1) {
      child.parent_frame = frame;
      child.sync();
    }
  }
  /**
   * TODO - Child Body transforms
   * Syncs the transforms of the Body's shapes. Generally this does not need to be called manually.
   */
  @:dox(hide)
  @:noCompletion
  private inline function sync_children():Void if (children.length > 0) for (child in children) child.sync();
  /**
   * Adds a new `Shape` to the Body based on the `ShapeOptions` passed in.
   * @param options
   * @param position The position in the Body's `shapes` array the Shape will be added to. If set to -1, the Shape is pushed to the end.
   * @return The newly created `Shape`.
   */
  public inline function create_shape(options:ShapeOptions, position:Int = -1):Shape {
    var s = Shape.get(options);
    return add_shape(s, position);
  }
  /**
   * Adds a `Shape` to the Body.
   * @param shape
   * @param position The position in the Body's `shapes` array the Shape will be added to. If set to -1, the Shape is pushed to the end.
   * @return The added `Shape`.
   */
  public inline function add_shape(shape:Shape, position:Int = -1):Shape {
    if (shapes.indexOf(shape) == -1) {
      if (position > -1) shapes[position] = shape;
      else shapes.push(shape);
      shape.set_parent(frame);
      dirty = true;
      update_static_bounds();
    }
    return shape;
  }

  public inline function remove_shape(shape:Shape):Shape {
    if (shapes.remove(shape)) {
      shape.set_parent();
      dirty = true;
      update_static_bounds();
    }
    return shape;
  }
  /**
   * Syncs the transforms of the Body's shapes. Generally this does not need to be called manually.
   */
  public inline function sync_shapes():Void if (shapes.length > 0) for (shape in shapes) shape.sync();
  /**
   * Clears all Shapes from the Body, releasing them to their respective pools.
   */
  public inline function clear_shapes() {
    for (shape in shapes) shape.put();
    shapes.resize(0);
  }
  /**
   * Gets the Body's position as a new `Vector2` (or sets the `Vector2`, if passed in).
   */
  public function get_position(?vec2:Vector2):Vector2 return vec2 == null ? frame.offset.clone() : vec2.set(frame.offset.x, frame.offset.y);

  public function set_position(x:Float = 0, y:Float = 0) {
    this.x = x;
    this.y = y;
  }
  /**
   * Adds forces to a Body's acceleration.
   * @param x
   * @param y
   */
  public function push(x:Float = 0, y:Float = 0) {
    acceleration.x += x;
    acceleration.y += y;
  }
  /**
   * If a Body has shapes, it will return an AABB `Rect` representing the bounds of its shapes relative to the Body's Position. If the Body does not have any shapes, this will return `null'.
   * @param rect Optional `Rect` to set the values to. If the Body does not have any shapes, the Rect will not be set.
   * @return Null<Rect>
   */
  public function bounds(?rect:Rect):Null<Rect> {
    if (shapes.length == 0) return null;

    var s = shapes[0];
    var min_x = s.left;
    var min_y = s.top;
    var max_x = s.right;
    var max_y = s.bottom;

    if (shapes.length > 1) for (i in 1...shapes.length) {
      var shape = shapes[i];
      if (shape.left < min_x) min_x = shape.left;
      if (shape.top < min_y) min_y = shape.top;
      if (shape.right > max_x) max_x = shape.right;
      if (shape.bottom > max_y) max_y = shape.bottom;
    }

    return rect == null ? Rect.get_from_min_max(min_x, min_y, max_x, max_y) : rect.set_from_min_max(min_x, min_y, max_x, max_y);
  }
  /**
   * If the Body is attached to a World, it is removed.
   * @return The detached Body.
   */
  public inline function remove():Body {
    if (world != null) world.remove(cast this);
    if (quadtree_data != null && quadtree_data.bounds != null) quadtree_data.bounds.put();
    return this;
  }
  /**
   * Checks if the Body is Dynamic (if it's mass is greater than 0).
   * @return  body.mass > 0
   */
  public inline function is_dynamic() return mass > 0;
  /**
   * Checks if the Body is Static (if it's mass is equal to 0).
   * @return  body.mass == 0
   */
  public inline function is_static() return mass <= 0;
  /**
   * If the Body is Static, update it's Quadtree Bounds.
   */
  public inline function update_static_bounds() {
    if (is_static() && world != null) {
      bounds(quadtree_data.bounds);
      world.static_quadtree.update(quadtree_data);
    }
  }
  /**
   * Returns true if the Body has moved since the last `Physics.step()`.
   */
  public inline function moved() return !x.equals(last_x, 0.001) || !y.equals(last_y, 0.001) || !rotation.equals(last_rotation, 0.001);
  /**
   * Disposes the Body. DO NOT use the Body after disposing it, as it could lead to null reference errors.
   */
  public function dispose() {
    remove();
    for (shape in shapes) shape.put();
    shapes = null;
    // TODO - dispose (or remove?) children Bodies
    velocity = null;
    max_velocity = null;
    drag = null;
    data = null;
    on_move = null;
    on_rotate = null;
    quadtree_data = null;
  }

  function toString() return 'Body: {id: $id, x: $x, y: $y, rotation: $rotation}';

  inline function get_x() return frame.offset.x;

  inline function get_y() return frame.offset.y;

  inline function get_rotation() return frame.angleDegrees;

  inline function get_shape() return shapes[0];

  // setters
  inline function set_x(value:Float):Float {
    if (value != frame.offset.x) {
      dirty = true;

      frame.offset = frame.offset.set(value, y);
      sync_shapes();
      // TODO - Child Body transforms
      // sync_children();

      update_static_bounds();

      if (on_move != null) on_move(frame.offset.x, frame.offset.y);
    }

    return frame.offset.x;
  }

  inline function set_y(value:Float):Float {
    if (value != frame.offset.y) {
      dirty = true;

      frame.offset = frame.offset.set(x, value);
      sync_shapes();
      // TODO - Child Body transforms
      // sync_children();

      update_static_bounds();

      if (on_move != null) on_move(frame.offset.x, frame.offset.y);
    }
    return frame.offset.y;
  }

  inline function set_shape(value:Shape) {
    if (shapes[0] != null) shapes[0].put();
    shapes[0] = value;
    shapes[0].set_parent(frame);
    dirty = true;
    update_static_bounds();
    return shapes[0];
  }

  inline function set_rotation(value:Float):Float {
    if (value != frame.angleDegrees) {
      dirty = true;

      frame.angleDegrees = value;
      sync_shapes();
      // TODO - Child Body transforms
      // sync_children();

      update_static_bounds();

      if (on_rotate != null) on_rotate(rotation);
    }

    return frame.angleDegrees;
  }

  inline function set_mass(value:Float):Float {
    if (value < 0.0001) {
      mass = inverse_mass = 0;
      update_static_bounds();
    }
    else {
      // If the Body was previously Static, remove it from the static quadtree
      if (is_static() && world != null) {
        world.static_quadtree.remove(quadtree_data);
      }
      mass = value;
      inverse_mass = 1 / mass;
    }
    return mass;
  }

  static function get_defaults():BodyOptions return {
    kinematic: false,
    mass: 1,
    x: 0,
    y: 0,
    rotation: 0,
    elasticity: 0,
    velocity_x: 0,
    velocity_y: 0,
    rotational_velocity: 0,
    max_velocity_x: 0,
    max_velocity_y: 0,
    max_rotational_velocity: 10000,
    drag_x: 0,
    drag_y: 0,
    gravity_scale: 1
  }
}
