CREATE TABLE `toon_dungeon_times` (
	`week` integer NOT NULL,
	`leader` text NOT NULL,
	`name` text NOT NULL,
	`secs` integer NOT NULL,
	`classes` text NOT NULL,
	`at` integer NOT NULL,
	PRIMARY KEY(`week`, `leader`)
);
--> statement-breakpoint
CREATE INDEX `toon_dungeon_times_week_secs` ON `toon_dungeon_times` (`week`,`secs`);
