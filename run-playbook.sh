#!/usr/bin/env bash
# Shortcut for running the `ansible-playbook` command.


HELP="
Specify the environment, eg:

	$ ./run-playbook.sh --env vagrant

Optionally specify tags and/or app. eg:

	$ ./run-playbook.sh --env vagrant --tags \"foo,bar\" --app appname

or, shorter:

	$ ./run-playbook.sh -e vagrant -t \"foo,bar\" -a appname
"

# Default variables.
ENVIRONMENT=""
TAGS=""
APP=""

# Function to display error message and exit.
echoerr() { echo -e "$@" 1>&2; exit 1; }


# While each of the arguments.
while [[ $# > 1 ]]
do
key="$1"


# Set variables based on arguments.
case $key in
	-e|--env)
	ENVIRONMENT="$2"
	shift # past argument
	;;
	-t|--tags)
	TAGS="$2"
	shift # past argument
	;;
	-a|--app)
	APP="$2"
	shift # past argument
	;;
	--default)
	DEFAULT=YES
	;;
	*)
			# unknown option
	;;
esac
shift # past argument or value
done


# Some error case I don't fully understand.
if [[ -n $1 ]]; then
	echo "Invalid argument option supplied: $1"
	echoerr $HELP
fi


# Add new possible environments and their ansible-playbook commands here.

if [ "$ENVIRONMENT" = "vagrant" ]; then
	command="ansible-playbook  --private-key=.vagrant/machines/default/virtualbox/private_key --user=vagrant --connection=ssh --inventory-file=inventories/vagrant.ini -v vagrant.yml"

elif [ "$ENVIRONMENT" = "production" ]; then
	# This will only work once the server has been set up initially, using the root user.
	command="ansible-playbook --inventory-file=inventories/production.ini --user=deploy --sudo  -v --ask-sudo-pass production.yml"

elif [ "$ENVIRONMENT" = "staging" ]; then
	# This will only work once the server has been set up initially, using the root user.
	command="ansible-playbook --inventory-file=inventories/staging.ini --user=deploy --sudo  -v --ask-sudo-pass staging.yml"

else
	echoerr "
No environment supplied.
$HELP"
fi


extra_output=""

if [ "$TAGS" != "" ]; then
	command="$command --tags=\"$TAGS\""
	extra_output="Using tags: $TAGS"
fi

if [ "$APP" != "" ]; then
	command="$command --extra-vars=\"app=$APP\""
	extra_output="$extra_output\nFor app: $APP"
fi


echo "-----------------------------------------------------------------"
echo "Running Ansible playbook for the $ENVIRONMENT environment"
echo -e $extra_output
echo "-----------------------------------------------------------------"

eval $command

