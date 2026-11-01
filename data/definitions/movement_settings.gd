class_name MovementSettings
extends Resource
## Настройки движения игрока. Данные: data/content/balance/movement_settings.tres.
## В Inspector открываются у узла Player (поле Movement) или двойным щелчком по .tres.
## Значения по умолчанию нейтральные: баланс лежит только в .tres, а не в коде.
## Все числа в .tres стартовые, подобраны ассистентом, требуют проверки в игре.

@export_group("Скорости")
## Обычная ходьба.
@export_range(0.0, 30.0, 0.1, "suffix:м/с") var walk_speed: float = 0.0
## Спринт (Shift), работает при движении вперёд.
@export_range(0.0, 40.0, 0.1, "suffix:м/с") var sprint_speed: float = 0.0
## Ходьба в приседании.
@export_range(0.0, 20.0, 0.1, "suffix:м/с") var crouch_speed: float = 0.0

@export_group("Разгон и торможение")
## Разгон на земле. Больше — отзывчивее и «резче».
@export_range(0.0, 200.0, 1.0, "suffix:м/с²") var ground_acceleration: float = 0.0
## Торможение на земле, когда клавиши движения отпущены.
@export_range(0.0, 200.0, 1.0, "suffix:м/с²") var ground_deceleration: float = 0.0
## Набор скорости в воздухе по направлению ввода. Лишнюю скорость в воздухе не гасим: это инерция.
@export_range(0.0, 100.0, 1.0, "suffix:м/с²") var air_acceleration: float = 0.0

@export_group("Прыжок")
## Сила тяжести. Больше — быстрее падает и короче «висит» в воздухе.
@export_range(1.0, 100.0, 0.5, "suffix:м/с²") var gravity: float = 0.0
## Предел скорости падения.
@export_range(1.0, 100.0, 0.5, "suffix:м/с") var max_fall_speed: float = 0.0
## Высота первого прыжка.
@export_range(0.0, 6.0, 0.05, "suffix:м") var jump_height: float = 0.0
## Высота прыжка в воздухе.
@export_range(0.0, 6.0, 0.05, "suffix:м") var air_jump_height: float = 0.0
## Сколько прыжков в воздухе доступно (1 = двойной прыжок).
@export_range(0, 5, 1) var air_jumps: int = 0

@export_group("Тело")
@export_range(0.1, 1.0, 0.05, "suffix:м") var body_radius: float = 0.0
@export_range(0.5, 3.0, 0.05, "suffix:м") var stand_height: float = 0.0
@export_range(0.5, 3.0, 0.05, "suffix:м") var crouch_height: float = 0.0
## Высота глаз над ногами: стоя, в приседе и в подкате.
@export_range(0.2, 3.0, 0.05, "suffix:м") var stand_eye_height: float = 0.0
@export_range(0.2, 3.0, 0.05, "suffix:м") var crouch_eye_height: float = 0.0
@export_range(0.2, 3.0, 0.05, "suffix:м") var slide_eye_height: float = 0.0
## Скорость, с которой камера меняет высоту при приседании и подкате.
@export_range(0.5, 50.0, 0.5, "suffix:м/с") var eye_height_speed: float = 0.0
## Насколько далеко пол «подтягивает» персонажа вниз при ходьбе по краю и склону.
@export_range(0.0, 1.0, 0.05, "suffix:м") var floor_snap_length: float = 0.0

@export_group("Подкат")
## С какой горизонтальной скорости Ctrl превращается в подкат. Ниже скорости ходьбы: подкат
## идёт и с обычной ходьбы. Хотите подкат только со спринта, поставьте значение выше скорости ходьбы.
@export_range(0.0, 40.0, 0.1, "suffix:м/с") var slide_min_speed: float = 0.0
## Множитель скорости на старте подката (1.15 = на 15% быстрее).
@export_range(1.0, 2.0, 0.01, "suffix:x") var slide_start_boost: float = 0.0
## Потолок, до которого рывок может поднять скорость. Быстрее входящую скорость не режем.
@export_range(0.0, 50.0, 0.1, "suffix:м/с") var slide_max_speed: float = 0.0
## Линейное торможение подката. Больше — короче подкат.
@export_range(0.0, 60.0, 0.5, "suffix:м/с²") var slide_deceleration: float = 0.0
## Доворот клавишами влево/вправо.
@export_range(0.0, 360.0, 1.0, "suffix:°/с") var slide_steer_degrees_per_second: float = 0.0

@export_group("Рывок")
## Сколько зарядов рывка у игрока.
@export_range(0, 10, 1) var dash_charges_max: int = 0
## За сколько секунд восстанавливается один заряд. Заряды восстанавливаются по очереди, пока их не станет максимум.
@export_range(0.1, 30.0, 0.1, "suffix:с") var dash_recharge_time: float = 0.0
## Скорость во время рывка (по горизонтали, вертикальная скорость на это время гасится).
@export_range(1.0, 80.0, 0.5, "suffix:м/с") var dash_speed: float = 0.0
## Сколько длится рывок. Пролетаемое расстояние: скорость на время.
@export_range(0.05, 1.0, 0.01, "suffix:с") var dash_duration: float = 0.0
## Скорость, с которой игрок выходит из рывка (по направлению рывка). Выше скорости ходьбы — небольшой разгон после.
@export_range(0.0, 40.0, 0.5, "suffix:м/с") var dash_exit_speed: float = 0.0
## Сколько секунд от начала рывка игрок неуязвим: урон и снаряды его не задевают.
@export_range(0.0, 1.0, 0.01, "suffix:с") var dash_invulnerability: float = 0.0
## Нажатие Shift короче этого времени считается касанием (рывок), длиннее — удержанием (спринт).
@export_range(0.05, 0.6, 0.01, "suffix:с") var dash_tap_time: float = 0.0
## Насколько расширяется угол обзора в рывке (ощущение скорости).
@export_range(0.0, 30.0, 0.5, "suffix:°") var dash_fov_kick: float = 0.0
