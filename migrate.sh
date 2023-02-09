#!/usr/bin/env bash

# MIT License
# 
# Copyright (c) 2023 Nathan Seymour
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Fancy colors
# https://stackoverflow.com/a/28938235
# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Underline
UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow
On_Blue='\033[44m'        # Blue
On_Purple='\033[45m'      # Purple
On_Cyan='\033[46m'        # Cyan
On_White='\033[47m'       # White

# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White

# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\033[0;100m'   # Black
On_IRed='\033[0;101m'     # Red
On_IGreen='\033[0;102m'   # Green
On_IYellow='\033[0;103m'  # Yellow
On_IBlue='\033[0;104m'    # Blue
On_IPurple='\033[0;105m'  # Purple
On_ICyan='\033[0;106m'    # Cyan
On_IWhite='\033[0;107m'   # White

# Get current directory: https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  	DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  	SOURCE=$(readlink "$SOURCE")
  	[[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

# Exit on errors
die() {
	printf "$Red"

	if [[ -n "$1" ]]; then
		echo "Error: $1"
	else
		echo "Error: Who the fuck killed me?!"
	fi

	printf "$Color_Off"

	exit 1
}

# Check for required dependencies
mysql --version > /dev/null || die "MySQL not found!"
openssl version > /dev/null || die "OpenSSL not found!"

# Make migration directory
mkdir -p "$DIR/migration"

# Configuration option
SAMPLE_ENV_FILE=$(cat << EOF
# Database Migration
DB_HOST=
DB_PORT=
DB_USER=
DB_PASSWORD=
DB_NAME=
EOF
)

if [[ "$1" == "configure" ]]; then
    if [[ ! -f "$DIR/.migration.env" ]]; then 
        echo "Creating new configuration in '$DIR/.migration.env'..."
        echo "$SAMPLE_ENV_FILE" > "$DIR/.migration.env"
        echo "Be sure to add .migration.env to your .gitignore file!"

        exit 0
    else
        echo "Configuration file already present in $DIR/.migration.env:"

		printf "\n"
        cat "$DIR/.migration.env"
		printf "\n" 

        echo "Delete it to create a new one!"

        exit 1
    fi
fi

# Security checks
printf "$Red"
if [[ ! -f "$DIR/.gitignore" ]]; then
	printf "\n"
    echo "WARNING: There is no .gitignore present in $DIR"
    echo "You may be leaking database credentials if you commit these directory contents!"
	printf "\n"
else
    RES=$(cat .gitignore | grep ".migration.env")

    if [[ "$?" -ne 0 ]]; then
		printf "\n"
        echo "WARNING: .migration.env is not included in your .gitignore!"
        echo "You may be leaking database credentials if you commit these directory contents!"
		printf "\n"
    fi
fi
printf "$Color_Off"

# Get the current configuration
source .migration.env

# Files
# - migration_template.sql
MIGRATION_TEMPLATE=$(cat << EOF
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
EOF
)

# init.sql
INIT=$(cat << EOF
CREATE TABLE __migration (
    version INTEGER PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    relative_path VARCHAR(200) NOT NULL,
    creation_date DATETIME NOT NULL,
    applied BOOLEAN NOT NULL,
    application_hash VARCHAR(100),
    ext INTEGER UNSIGNED
);
EOF
)

# Routines
run_sql_file() {
	mysql --batch -sN -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$1" || die "Failed to execute file '$1'"
	return $?
}

run_sql_query() {
	mysql --batch -sN -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "$1" || die "Failed to execute query '$1'"
	return $?
}

get_current_version() {
	local VERSION
	VERSION=$(run_sql_query "SELECT MAX(version) FROM __migration WHERE applied=true;")

	if [[ "$VERSION" == "NULL" ]]; then
		return 1
	else
		echo "$VERSION"
		return 0
	fi
}

get_next_version() {
	local VERSION
	VERSION=$(run_sql_query "SELECT MIN(version) FROM __migration WHERE applied=false;")

	if [[ "$VERSION" == "NULL" ]]; then
		get_current_version
		return 1
	else
		echo "$VERSION"
		return 0
	fi
}

calculate_file_hash() {
	FILE_HASH_RAW=$(openssl dgst -sha256 "$1")
    FILE_HASH=${FILE_HASH_RAW:(-64):64}

    echo "$FILE_HASH"
}

print_db_version() {
	CURRENT_VERSION=$(get_current_version) || die "Unable to get the current version. What the hell did you do to my database?"

	MIGRATION=$(run_sql_query "SELECT version, name, relative_path, application_hash FROM __migration WHERE version='$CURRENT_VERSION'")
	IFS=$'\t' read -r VERSION NAME RELATIVE_PATH APPLICATION_HASH <<< "$MIGRATION"

	echo "Database schema at v$VERSION '$NAME' with hash SHA256($APPLICATION_HASH)"
}

do_migration_up() {
	NEXT_VERSION=$(get_next_version) || die "Already updated to the latest version! Don't be a greedy Garry!"

	MIGRATION=$(run_sql_query "SELECT version, name, relative_path FROM __migration WHERE version='$NEXT_VERSION'")
	IFS=$'\t' read -r VERSION NAME RELATIVE_PATH <<< "$MIGRATION"

	echo "Running migration '$NAME' ($RELATIVE_PATH)..."

	if [[ ! -f "$DIR/$RELATIVE_PATH" ]]; then
		die "Unable to open $RELATIVE_PATH. Did you delete it, you silly goose?"
	fi

	MIGRATION_UP=$(sed -n '/\/\*START MIGRATION UP\*\//,/\/\*END MIGRATION UP\*\//p' "$DIR/$RELATIVE_PATH")
	if [[ -z "$MIGRATION_UP" ]]; then
		die "Failed to parse $RELATIVE_PATH. Stop fucking with the comments. They're important!"
	fi

	# Apply migration
	run_sql_query "$MIGRATION_UP"

	# Calculate file hash
	MIGRATION_HASH=$(calculate_file_hash "$DIR/$RELATIVE_PATH")

	# Log migration in DB
	run_sql_query "UPDATE __migration SET applied=true, application_hash='$MIGRATION_HASH' WHERE version='$VERSION';"

	# Inform user
	print_db_version
}

do_migration_down() {
	CURRENT_VERSION=$(get_current_version) || die "All migrations have already been undone. Try 'rm -rf /' just to be sure."

	MIGRATION=$(run_sql_query "SELECT version, name, relative_path, application_hash FROM __migration WHERE version='$CURRENT_VERSION'")
	IFS=$'\t' read -r VERSION NAME RELATIVE_PATH APPLICATION_HASH <<< "$MIGRATION"

	echo "Undoing migration '$NAME' ($RELATIVE_PATH)..."

	if [[ ! -f "$DIR/$RELATIVE_PATH" ]]; then
		die "Unable to open $RELATIVE_PATH. Did you delete it, you silly goose?"
	fi

	MIGRATION_DOWN=$(sed -n '/\/\*START MIGRATION DOWN\*\//,/\/\*END MIGRATION DOWN\*\//p' "$DIR/$RELATIVE_PATH")
	if [[ -z "$MIGRATION_DOWN" ]]; then
		die "Failed to parse $RELATIVE_PATH. Stop fucking with the comments. They're important!"
	fi

	# Calculate file hash
	MIGRATION_HASH=$(calculate_file_hash "$DIR/$RELATIVE_PATH")

	# Verify that hashes are the same
	if [[ ! "$MIGRATION_HASH" == "$APPLICATION_HASH" ]]; then
		die "Migration file has been chanced since the upgrade. Downgrade NOT APPLIED. You thought you were a sneaky little snake, and I wouldn't notice, didn't you?"
	fi

	# Apply migration
	run_sql_query "$MIGRATION_DOWN"

	# Log migration in DB
	run_sql_query "UPDATE __migration SET applied=false, application_hash='$MIGRATION_HASH' WHERE version='$VERSION';"

	# Inform user
	echo "Successfully downgraded migration v$VERSION '$NAME' with hash SHA256($MIGRATION_HASH)"
	print_db_version
}

print_usage() {
	echo "Usage: $0 {init|create <name>|up|down|updown|update|version}"

	cat << EOM
Commands:
	- init              Initialize the migration table in database
    - configure         Create an empty config file (.migration.env)
	- create <name>     Create a new migration
	- up                Apply the next (single) migration
	- down              Undo one migration
	- updown            Apply and immediately undo migration. (For testing)
	- version           Print the current database version
EOM
}

initialize_db() {
	run_sql_query "$INIT"
}

# Handle action
case "$1" in
	init)
		initialize_db

		# TODO: Scan in existing migration files

		echo "Initialized database for migrations. Hopefully my shitty code won't destroy your server. May God have mercy on your soul!"
		;;

	create)
		MIGRATION_NAME="$2"

		# Name must be valid
		if [[ -z "$MIGRATION_NAME" ]]; then
			die "You must provide a name for the new migration!"
		fi

		TIMESTAMP=$(date '+%Y%m%d%H%M%S')
		MIGRATION_UID="${TIMESTAMP}_$MIGRATION_NAME"

		MIGRATION_EXISTS=$(run_sql_query "SELECT version FROM __migration WHERE name='$MIGRATION_NAME'")
		if [[ -n "$MIGRATION_EXISTS" ]]; then
			die "A migration by that name ($MIGRATION_NAME) already exists!"
		fi

		RELATIVE_PATH="migration/${MIGRATION_UID}.sql"

		echo "Creating migration '$MIGRATION_NAME' ($RELATIVE_PATH)..."
		run_sql_query "INSERT INTO __migration(name, relative_path, creation_date, applied) VALUES('$MIGRATION_NAME', '$RELATIVE_PATH', '$TIMESTAMP', false);"
		echo "$MIGRATION_TEMPLATE" > "$DIR/$RELATIVE_PATH"
		;;

	up)
		do_migration_up
		;;

	down)
		do_migration_down
		;;

	updown)
		do_migration_up
		do_migration_down
		;;

	version)
		print_db_version
		;;

	*)
		print_usage
		printf "\n"
		die "Invalid command '$1'"
		;;
esac