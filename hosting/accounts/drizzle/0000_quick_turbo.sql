CREATE TABLE `toon_rate_limits` (
	`bucket` text PRIMARY KEY NOT NULL,
	`count` integer NOT NULL,
	`expires_at` integer NOT NULL,
	CONSTRAINT "toon_rate_limits_count_check" CHECK("toon_rate_limits"."count" > 0)
);
--> statement-breakpoint
CREATE INDEX `toon_rate_limits_expiry` ON `toon_rate_limits` (`expires_at`);--> statement-breakpoint
CREATE TABLE `toon_save_snapshots` (
	`user_id` text NOT NULL,
	`revision` integer NOT NULL,
	`bundle` text NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `revision`),
	FOREIGN KEY (`user_id`) REFERENCES `toon_users`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "toon_save_snapshots_revision_check" CHECK("toon_save_snapshots"."revision" > 0)
);
--> statement-breakpoint
CREATE TABLE `toon_saves` (
	`user_id` text PRIMARY KEY NOT NULL,
	`revision` integer DEFAULT 0 NOT NULL,
	`bundle` text NOT NULL,
	`updated_at` integer,
	FOREIGN KEY (`user_id`) REFERENCES `toon_users`(`id`) ON UPDATE no action ON DELETE cascade,
	CONSTRAINT "toon_saves_revision_check" CHECK("toon_saves"."revision" >= 0)
);
--> statement-breakpoint
CREATE TABLE `toon_sessions` (
	`token_hash` text PRIMARY KEY NOT NULL,
	`user_id` text NOT NULL,
	`created_at` integer NOT NULL,
	`expires_at` integer NOT NULL,
	FOREIGN KEY (`user_id`) REFERENCES `toon_users`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `toon_sessions_user` ON `toon_sessions` (`user_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `toon_sessions_expiry` ON `toon_sessions` (`expires_at`);--> statement-breakpoint
CREATE TABLE `toon_users` (
	`id` text PRIMARY KEY NOT NULL,
	`username` text NOT NULL,
	`password_salt` text NOT NULL,
	`password_hash` text NOT NULL,
	`password_iterations` integer NOT NULL,
	`recovery_hash` text NOT NULL,
	`created_at` integer NOT NULL,
	CONSTRAINT "toon_users_password_iterations_check" CHECK("toon_users"."password_iterations" >= 100000)
);
--> statement-breakpoint
CREATE UNIQUE INDEX `toon_users_username_unique` ON `toon_users` (`username`);