# Журнал ассетов

Каждый внешний файл (текстура, шрифт, модель) записывается сюда: источник, лицензия, что изменено, где используется. Если лицензия выведена по имени файла и не проверена, это помечено.

## Структура

```
assets/
  source/        .blend, скрипты Blender, исходники (папка с .gdignore, Godot её не видит)
    blend/  scripts/  downloads/
  reference/     скриншоты игр-референсов (.gdignore, не для репозитория)
  models/        .glb: environment/kit, enemies, weapons, props
  textures/
    pbr/         оригиналы 1K (ambientCG, Poly Haven), не изменяются
    lib/         рабочие копии 256-512 px для игры (создаёт скрипт)
    trims/ decals/ posters/
  materials/     библиотека материалов .tres (<группа>/<имя>.tres)
  fonts/         шрифты семейство за семейством с файлом лицензии
  placeholders/  серые заглушки (резерв до полной замены)
```

## Текстуры (`textures/pbr`)

Состояние на 01.11.2026: 71 набор, разрешение 1K. 31 набор из ambientCG (`Имя_1K-JPG_*`, лицензия CC0), 40 наборов из Poly Haven (`имя_diff|disp|nor_gl|rough_1k`, лицензия CC0). **Лицензии выведены по формату имён файлов, источник не проверен.**

Рабочие копии 512 px собирает `source/scripts/build_texture_lib.py` в `textures/lib/<папка>/`: `_c.jpg` цвет (AO подмешан с силой 0.6), `_n.png` нормали OpenGL, `_r.jpg` roughness, `_m.jpg` metalness (только непустой). Карты: c цвет, n нормали, r roughness, m metalness. Материалы `assets/materials/<папка>/<набор>.tres` (обычные UV) и `<набор>_tri.tres` (мировой триплпланар) создаёт `source/scripts/build_materials.gd`. Оригиналы в `textures/pbr` не изменяются; папка закрыта файлом `.gdignore`, чтобы Godot их не импортировал. Правило: ни один набор не остаётся без дела; столбец «Использован» заполняется по ходу серии.

| Набор | Источник | Папка | Карты в игре | Роль (план) | Использован |
|---|---|---|---|---|---|
| `brick_pavement_04` | Poly Haven | brick | cnr | мощение хаба: площадь, дорожки | — |
| `double_brick_floor` | Poly Haven | brick | cnr | полы старых секций и подвалов | — |
| `factory_brick` | Poly Haven | brick | cnr | стены старых цехов завода | — |
| `red_bricks_04` | Poly Haven | brick | cnr | стены домов хаба | — |
| `stenciled_brick_floor` | Poly Haven | brick | cnr | полы с трафаретной разметкой (стрелки, номера) | — |
| `concrete_007` | ambientCG | concrete | cnr | стены зон, светлая ступень | — |
| `concrete_023` | ambientCG | concrete | cnr | стены зон, средняя ступень | — |
| `concrete_041b` | ambientCG | concrete | cmnr | колонны и балки | — |
| `concrete_042a` | ambientCG | concrete | cnr | основной бетон стен и потолков | — |
| `concrete_043a` | ambientCG | concrete | cnr | потолки и плиты, тёмная ступень | — |
| `concrete_044c` | ambientCG | concrete | cnr | шахты и глубокие секции | — |
| `corrugated_steel_007b` | ambientCG | concrete | cmnr | обшивка ворот и контейнеров | — |
| `concrete_floor_01` | Poly Haven | concrete | cnr | полы коридоров | — |
| `concrete_floor_worn_001` | Poly Haven | concrete | cnr | полы боевых комнат (истёртый) | — |
| `cracked_concrete_02` | Poly Haven | concrete | cnr | укрытия-блоки, разрушенные участки | — |
| `dirty_concrete` | Poly Haven | concrete | cnr | стены грязных секций | — |
| `hangar_concrete_floor` | Poly Haven | concrete | cnr | полы больших залов | — |
| `painted_concrete` | Poly Haven | concrete | cnr | стены служебных комнат с краской | — |
| `denim_fabric_05` | Poly Haven | fabric | cmnr | спецодежда и мешки в хабе | — |
| `fabric_leather_01` | Poly Haven | fabric | cnr | кресла и сиденья | — |
| `fabric_leather_02` | Poly Haven | fabric | cnr | прилавки и обивка | — |
| `fabric_pattern_05` | Poly Haven | fabric | cnr | шторы и навесы хаба | — |
| `hessian_230` | Poly Haven | fabric | cmnr | мешковина и мешки | — |
| `leather_red_02` | Poly Haven | fabric | cnr | акцент: кресла, ремни, рукояти | — |
| `worn_corrugated_iron` | Poly Haven | fabric | cnr | ворота и крыши хаба | — |
| `carpet_006` | ambientCG | floor | cnr | ковры магазина | — |
| `carpet_012` | ambientCG | floor | cnr | ковры служебных комнат | — |
| `carpet_016` | ambientCG | floor | cnr | ковры и коврики хаба | — |
| `garage_floor` | Poly Haven | floor | cnr | полы гаражных зон | — |
| `old_linoleum_flooring_01` | Poly Haven | floor | cnr | полы служебных комнат и магазина | — |
| `raw_wooden_floor_01` | Poly Haven | floor | cnr | деревянные полы хаба, ящики | — |
| `ribbed_corduroy` | Poly Haven | floor | cmnr | мягкая мебель хаба | — |
| `rocky_terrain_02` | Poly Haven | floor | cnr | камни и скалы вокруг хаба | — |
| `square_floor_patern_01` | Poly Haven | floor | cnr | плиточные полы хаба | — |
| `brown_mud_leaves_01` | Poly Haven | ground | cnr | земля и клумбы хаба | — |
| `dry_decay_leaves` | Poly Haven | ground | cnr | листва в трещинах завода | — |
| `forest_leaves_03` | Poly Haven | ground | cnr | подлесок хаба | — |
| `grass_ground` | Poly Haven | ground | cnr | трава хаба | — |
| `leafy_grass` | Poly Haven | ground | cnr | густая зелень хаба | — |
| `corrugated_steel_007a` | ambientCG | metal | cmnr | обшивка стен и ворот | — |
| `diamond_plate_009` | ambientCG | metal | cmnr | рампы и платформы | — |
| `metal_023` | ambientCG | metal | cmnr | трубы и короба | — |
| `metal_025` | ambientCG | metal | cmnr | шкафы и корпуса станков | — |
| `metal_056c` | ambientCG | metal | cmnr | корпуса турелей | — |
| `painted_metal_004` | ambientCG | metal | cmnr | красный: опасные бочки, аварийные двери | — |
| `painted_metal_006` | ambientCG | metal | cmnr | двери и бочки по стихиям | — |
| `painted_metal_008` | ambientCG | metal | cmnr | корпуса врагов и оружия | — |
| `painted_metal_009` | ambientCG | metal | cnr | корпуса врагов и оружия | — |
| `sheet_metal_001` | ambientCG | metal | cmnr | листовые панели стен | — |
| `sheet_metal_002` | ambientCG | metal | cmnr | панели и укрытия-стены | — |
| `sheet_metal_004` | ambientCG | metal | cmnr | панели и укрытия-стены | — |
| `blue_metal_plate` | Poly Haven | metal | cnr | оборудование, корпуса ОИТП | — |
| `corrugated_iron` | Poly Haven | metal | cmnr | контейнеры, корпуса «СельхозОборона» | — |
| `green_metal_rust` | Poly Haven | metal | cnr | износ: «брак» по качеству | — |
| `metal_plate` | Poly Haven | metal | cmnr | рампы, платформы, корпуса врагов | — |
| `rubber_004` | ambientCG | other | cnr | рукояти, шины, уплотнители дверей | — |
| `painted_plaster_006` | ambientCG | plaster | cnr | тёплые стены хаба | — |
| `painted_plaster_015` | ambientCG | plaster | cnr | стены служебных комнат | — |
| `plaster_007` | ambientCG | plaster | cnr | стены и потолки служебных комнат | — |
| `blue_plaster_wall` | Poly Haven | plaster | cnr | стены отдела, холодный акцент | — |
| `blue_plaster_weathered` | Poly Haven | plaster | cnr | стены отдела, облезлые | — |
| `red_plaster_weathered` | Poly Haven | plaster | cnr | стены отдела, тёплый акцент | — |
| `white_rough_plaster` | Poly Haven | plaster | cnr | стены магазина | — |
| `rust_009` | ambientCG | rust | cnr | накладки износа и потёки | — |
| `tiles_132c` | ambientCG | tiles | cnr | полы магазина и шлюзов | — |
| `tiles_133d` | ambientCG | tiles | cnr | стены санитарных зон | — |
| `tiles_135c` | ambientCG | tiles | cnr | полы шлюзов | — |
| `tiles_137c` | ambientCG | tiles | cnr | полы хаба | — |
| `floor_tiles_09` | Poly Haven | tiles | cnr | полы хаба, плитка | — |
| `seaworn_stone_tiles` | Poly Haven | tiles | cnr | площадь хаба, камень | — |
| `peeling_painted_wall` | Poly Haven | wall | cnr | коридоры с облупившейся краской | — |

## Шрифты (`fonts`)

| Шрифт | Лицензия | Файл лицензии | Роль |
|---|---|---|---|
| Stalinist One | OFL (шапка: Alexey Maslov, Jovanny Lemonad) | `OFL (2).txt` | крупные заголовки, номера отделов |
| Russo One | OFL (по знанию, не проверено) | **нет** | цифры и ключевые надписи HUD |
| PT Sans Narrow | OFL (ParaType) | `OFL (3).txt` | основной текст, карточки |
| PT Mono | OFL (ParaType) | `OFL.txt` | числа, терминалы |
| IBM Plex Mono | OFL (IBM Corp.) | `OFL (4).txt` | числа, статистика |

Привязка файлов `OFL*.txt` к шрифтам сделана по шапкам, по именам файлов её не видно.

## Модели и материалы

Пока пусто. Для каждой модели: имя `.glb`, `.blend`-источник, скрипт, число треугольников, материалы библиотеки.
