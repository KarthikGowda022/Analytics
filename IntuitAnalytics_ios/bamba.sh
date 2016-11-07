#!/bin/bash

# bamba.sh

# For debug turn on:
#set -x

SCRIPT_VERSION=1.0.4

DEPENDENCY_FILE="bambaFile" # Default location
DEPENDENCY_OUTPUT_LOCATION=./Dependencies
DEPENDENCY_GIT=https://github.intuit.com/CTO-DevMobileOpenSource/Bamba.git
LOCAL_DYLIB_REPO="/tmp/LocalDyLibRepo/"
DEPENDENCY_TEMPLATE="DEPENDENCIES=\"
DYLIB 1.0.1
\"

NEXUS_REPOS=\"https://iapps.corp.intuit.net/nexus/service/local/artifact/maven\" # Space separated list
REPOS=\"Intuit.Shared.iOS-releases Intuit.Shared.iOS-snapshots\" # Space separated list
GROUP_ID=\"com.intuit.scs\"
DEPENDENCY_VERSION=${SCRIPT_VERSION}
"
PRINT_ENV=false
DEBUG_ON=false
TEMP_DIRECTORY=/tmp/DyLibDownloadDirectory/

# Loop through the arguments
while [[ $# > 0 ]] ; do
	case $1 in
	    -v|--verbose)
			PRINT_ENV=true
	    ;;
	    -h|--help)
		    echo "bamba, version ${SCRIPT_VERSION}"
			echo ""
			echo "usage: bamba [-h|--help] [-v|--verbose] [dependencyFileName]"
			exit 0
	    ;;
	    -d|--debug)
			DEBUG_ON=true
	    ;;
	    *)
			if ! [[ $1 == *"-"* ]] ; then
				DEPENDENCY_FILE=$1
				echo "Using ${DEPENDENCY_FILE} as the dependency file."
			else
				echo "Unrecognized $1"
			fi
	    ;;
	esac
	shift
done

# Create dependency file if necessary
if [ ! -e ${DEPENDENCY_FILE} ] ; then
	echo "Creating dependency file: ${DEPENDENCY_FILE}"
	echo "${DEPENDENCY_TEMPLATE}" > ${DEPENDENCY_FILE}
	exit 1
fi

# Read dependency file
source ${DEPENDENCY_FILE}

# Print verbose info.
if [ ${PRINT_ENV} = true ]; then
	echo ""
	echo "Environment:"
	echo "SCRIPT_VERSION=${SCRIPT_VERSION}"
	echo "DEPENDENCY_GIT=${DEPENDENCY_GIT}"
	echo "DEPENDENCY_FILE=${DEPENDENCY_FILE}"
	echo "NEXUS_REPOS=${NEXUS_REPOS}"
	echo "REPOS=${REPOS}"
	echo "GROUP_ID=${GROUP_ID}"
	echo "DEPENDENCY_VERSION=${DEPENDENCY_VERSION}"
	echo ""
fi

# Turn debug on
if [ ${DEBUG_ON} = true ]; then
	set -x
fi

# Error out if versions are incompatible
# Below we are using the pattern matching function ${parameter%%word}
# (https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)
# where the word being used to search is the pattern, .*, which in this case will match the
# strip everything but the major version from a string like 1.2.3.4-test
if [ "${SCRIPT_VERSION%%.*}" != "${DEPENDENCY_VERSION%%.*}" ] ; then
	echo "The dependencies are from version ${DEPENDENCY_VERSION} which is not compatible with ${SCRIPT_VERSION}"
	exit 2
fi

# Read the latest version in git
LATEST_VERSION=`git ls-remote -q --tags ${DEPENDENCY_GIT} 2>/dev/null  | grep -v "\^{}" | sed "s/.*refs\/tags\///" | sort -g | tail -n 1`

# If a new version is available print it
if [ -n "${LATEST_VERSION}" ] && [ "${SCRIPT_VERSION}" != "${LATEST_VERSION}" ] ; then
	echo "The newer version ${LATEST_VERSION} is available."
fi

# Remove the dependencies folder
rm -rf ${DEPENDENCY_OUTPUT_LOCATION}

# Clean the dependencies folder
mkdir -p ${DEPENDENCY_OUTPUT_LOCATION}

# Clean local dylib repo location (this is the dylib repo location specified in the Build Phases script of our Xcode projects).
# Without doing this, the existence of the local dylib repo location causes any downloaded dylibs from this script to be overriden.
rm -rf ${LOCAL_DYLIB_REPO}

# Clean the temporary download directory
rm -rf ${TEMP_DIRECTORY}

# Make the temporary directory for downloading and unzipping
mkdir -p ${TEMP_DIRECTORY}

# Loop through each line in the dependencies
echo "${DEPENDENCIES}" | while read LINE ; do
	if [ !	 -n "${LINE}" ] ; then
		continue # If the line is empty, skip it
	fi
	
    # The () here converts a line of text into a list (auto-delimited by whitespace)
	LINE_COMPONENTS=( ${LINE} )
	
	DYLIB_NAME=${LINE_COMPONENTS[0]}
	DYLIB_VERSION=${LINE_COMPONENTS[1]}
	
	DYLIB_DOWNLOAD_LOCATION=${TEMP_DIRECTORY}/${DYLIB_NAME}
	DYLIB_LOCATION=${DEPENDENCY_OUTPUT_LOCATION}/${DYLIB_NAME}

	# Loop through all nexus repos
	for NEXUS in ${NEXUS_REPOS} ; do
		# Loop through all repos on nexus.
		# Yes this will do a multiplication table, it might be subpar, but this is not the intended use of these settings and is a sacrfice that I am willing to make
		for REPO in ${REPOS} ; do
			# If we can find the artifact
			RES=`curl -I -s -o /dev/null -w "%{http_code}" "${NEXUS}/resolve?r=${REPO}&g=${GROUP_ID}&a=${DYLIB_NAME}&v=${DYLIB_VERSION}&e=zip"`
			if [ $RES -eq 200 ] ; then
				# Then download the zip
				curl -s -o ${DYLIB_DOWNLOAD_LOCATION}.zip "${NEXUS}/content?r=${REPO}&g=${GROUP_ID}&a=${DYLIB_NAME}&v=${DYLIB_VERSION}&e=zip"
				break
			fi
		done
	done

	# If the zip exists
	if [ -f ${DYLIB_DOWNLOAD_LOCATION}.zip ] ; then
        # Clean up the any previous version of this lib, if it exists
        rm -rf ${DYLIB_DOWNLOAD_LOCATION}
        
		# Unzip
		unzip -q ${DYLIB_DOWNLOAD_LOCATION}.zip -d ${DYLIB_DOWNLOAD_LOCATION}
		
		# Copy from temp folder to final destination
		mv ${DYLIB_DOWNLOAD_LOCATION} ${DYLIB_LOCATION}
		
		# Delete the unnecessary files.
		rm ${DYLIB_DOWNLOAD_LOCATION}.zip
		rm -rf ${DYLIB_DOWNLOAD_LOCATION}
		
		echo "Downloaded ${DYLIB_NAME} of version ${DYLIB_VERSION}."
	else
		echo "The ${DYLIB_NAME} of version ${DYLIB_VERSION} was not found."
	fi
done

echo ""
