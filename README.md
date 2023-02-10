# migration.sh

_Because all other migration tools are garbage._

Just kidding, of course. This is just a simple migration tool for MySQL databases contained in a single shell script.

It only has two dependencies: 
- MySQL
- OpenSSl

And touts the following features:
- Creation of single-file migrations
- Database upgrading and rollbacks
- Hashing of migration files to warn you when they have been changed between upgrade and rollback

## Usage

### Configuring the tool

```BASH
./migrate.sh configure
```

This will create a `.migration.env` file for you to store your database credentials in:

```
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=example
DB_PASSWORD=password
DB_NAME=example
```

### Initializing the tool

```BASH
./migrate.sh init
```

This will create the necessary `__migration` table in your database that will track all of your migrations.

### Creating a new migration

```BASH
./migrate.sh create test
```

This will create a new migration in `migration/TIMESTAMP_test.sql`. It will be based on the following template:

```SQL
/* MIGRATION TEMPLATE */
/* DO NOT DELETE TEMPLATE COMMENTS! */

/* --- */

/*START MIGRATION UP*/

CREATE TABLE my_table (
    id INT PRIMARY KEY AUTO_INCREMENT
);

/*END MIGRATION UP*/

/* --- */

/*START MIGRATION DOWN*/

DROP TABLE my_table;

/*END MIGRATION DOWN*/
```

You should write SQL queries to setup the database how you need and then to completely undo your changes. In `migrate.sh`, the 'up' and 'down' SQL statements live in the same file. "What goes together, goes together." Don't delete the comments. They are important. 

### Migrating the database

```BASH
./migrate.sh up
./migrate.sh down
```

Both work just as expected.

### Getting help

```BASH
./migrate.sh usage
```

The usage screen prints:

```
Usage: ./migrate.sh [command] [args]
Commands:
        - init              Initialize the migration table in database
        - configure         Create an empty config file (.migration.env)
        - create <name>     Create a new migration
        - delete <name>     Delete a migration. MUST NOT BE APPLIED.
        - discover          Scan for untracked migrations in migration directory (Automatically performed on 'up')
        - up                Apply the next (single) migration
        - down              Undo one migration
        - updown            Apply and immediately undo migration (For testing)
        - version           Print the current database version
        - list              Show all migrations saved in the database
        - usage             Show this list
```