class_name CombatEnums
extends RefCounted
## Общие перечисления боя. Используются в данных (Resource) и коде: CombatEnums.Element.ACID и т.д.

## Стихии (02-combat-fps, №37). Даёт аксессуар оружия. Огонь пока заглушка.
enum Element { NONE, ACID, ELECTRIC, FROST, FIRE }

## Типы оружия (02-combat-fps): определяются корпусом. Нужны таблице уязвимостей.
enum WeaponType { PISTOL, REVOLVER, AKIMBO, SHOTGUN, ASSAULT_RIFLE, SEMI_AUTO_RIFLE, SMG, SNIPER, EXPLOSIVE }

## Классы врагов для таблицы уязвимостей (02-combat-fps, №21, №30).
enum EnemyClass { SWARM, ARMORED, HEAVY, RANGED }

## Характеристики оружия, которые могут сдвигать модификаторы, уклон производителя и особенности (№28, №70).
enum Stat { DAMAGE, FIRE_RATE, MAGAZINE_SIZE, RELOAD_TIME, SPREAD, RANGE, RECOIL, AIM_TIME, CRIT_CHANCE, MOVEMENT_SPREAD }

## Род названия корпуса: от него зависят формы прилагательных в названии оружия (№49, №70).
enum Gender { MASCULINE, FEMININE, NEUTER }

## Прицел корпуса: механический (целик и мушка) или оптика. Свойство корпуса (№28).
enum SightType { IRON, OPTIC }

## Что делает особенность: просто сдвигает характеристики, накладывает стихию или усиливает урон в ситуации.
enum FeatureKind { STATS, ELEMENT, SLIDE_DAMAGE, AIR_DAMAGE, MELEE_DAMAGE }
