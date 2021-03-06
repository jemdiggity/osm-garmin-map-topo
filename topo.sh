#!/bin/bash
#
# Generate for France a topographic gmapsupp.img file to use with Garmin GPS
# See : <http://wiki.openstreetmap.org/wiki/OSM_Map_on_Garmin/Contours_using_phygtmap>
# It uses the data from : 
# - OpenStreetMap : http://www.openstreetmap.org/copyright
# - Nasa : http://www2.jpl.nasa.gov/srtm/
#
# Encoding : UTF-8
# Licence : GPL v2
# Copyright Jean-Pascal Milcent, 2014
# Dependances : java, mkgmap, python, phyghtmap


DIR_BASE=$(pwd)
TIME_START=$(date +%s)
AREA="france"
AREA_NAME="France topo"
AREA_CODE="FR"
MAP_NAME=20130001
TO_MERGE="false"

while getopts "hc:a:n:i:m:f" option
do
	case $option in
		h)
			echo "Usage: map.sh [options]"
			echo "Options:"
			echo "-h		show this help message and exit."
			echo "-a		name of country (see download.geofabrik.de) for which you want to generate a Garmin img file. Default : france"
			echo "-n		name that you want to give to this map. Default : France topo"
			echo "-c		code that you want to give to this map. Default : FR"
			echo "-m		map name for the --mapnam mkgmap option. Default : 20130001"
			echo "-f		use this, if you want merge the gmapsupp.img file with another. Active the --remove-ovm-work-files option for mkgmap."
			;;
		a)
			AREA=$OPTARG
			;;
		n)
			AREA_NAME=$OPTARG
			;;
		c)
			AREA_CODE=$OPTARG
			;;
		m)
			MAP_NAME=$OPTARG
			;;
		f)
			TO_MERGE="true"
			;;
		:)
			echo "L'option $OPTARG requiert un argument"
			exit 1
			;;
		\?)
			echo "$OPTARG : option invalide"
			exit 1
			;;
	esac
done

# Functions
function displaytime {
	# Source : http://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
	local T=$1
	local D=$((T/60/60/24))
	local H=$((T/60/60%24))
	local M=$((T/60%60))
	local S=$((T%60))
	[[ $D > 0 ]] && printf '%d days ' $D
	[[ $H > 0 ]] && printf '%d hours ' $H
	[[ $M > 0 ]] && printf '%d minutes ' $M
	[[ $D > 0 || $H > 0 || $M > 0 ]] && printf 'and '
	printf '%d seconds\n' $S
};

# Load config
if [ -f ${DIR_BASE}/config.cfg ] ; then
	source ${DIR_BASE}/config.cfg
	echo -e "${Gra}Config : ${Gre}OK${RCol}"
else
	echo -e "\e[1;31mPlease configure the script by renaming the file 'config.defaut.cfg' to 'config.cfg.\e[0m"
	exit;
fi

# Check dependancies
type java >/dev/null 2>&1 || { echo >&2 -e "${Red}I require phyghtmap but it's not installed. Aborting.${RCol}"; exit 1; }
type phyghtmap >/dev/null 2>&1 || { echo >&2 -e "${Red}I require phyghtmap but it's not installed. Aborting. See : http://katze.tfiu.de/projects/phyghtmap/${RCol}"; exit 1; }

# Install mkgmap
if [ ! -d "${DIR_APP}/mkgmap-r${MKGMAP_VERSION}" ] ; then
	echo -e "${Yel}Downloading and configuring Mkgmap...${RCol}";
	cd ${DIR_APP}/
	if [ ! -d "${DIR_APP}/mkgmap-r${MKGMAP_VERSION}" ]; then
		rm -fR ${DIR_APP}/mkgmap-r*
		wget http://www.mkgmap.org.uk/download/mkgmap-r${MKGMAP_VERSION}.zip
		unzip mkgmap-r${MKGMAP_VERSION}.zip
		rm -f ${DIR_BIN}/mkgmap
		ln -s ${DIR_APP}/mkgmap-r${MKGMAP_VERSION} ${DIR_BIN}/mkgmap 
	fi
	cd ${DIR_BASE}
else
	echo -e "${Gra}Mkgmap r${MKGMAP_VERSION} : ${Gre}OK${RCol}"
fi

# Download ressources
if [ ! -f ${DIR_DATA}/sea_${SEA_VERSION}.zip ] ; then
	wget http://osm2.pleiades.uni-wuppertal.de/sea/${SEA_VERSION}/sea_${SEA_VERSION}.zip -O ${DIR_DATA}/sea_${SEA_VERSION}.zip
fi

# Configure style & data
if [ ! -f ${DIR_STYLE}/lines ] ; then
	cp ${DIR_STYLE}/lines.default ${DIR_STYLE}/lines
fi
if [ ! -f ${DIR_STYLE}/options ] ; then
	cp ${DIR_STYLE}/options.default ${DIR_STYLE}/options
fi
if [ ! -f ${DIR_STYLE}/version ] ; then
	cp ${DIR_STYLE}/version.default ${DIR_STYLE}/version
fi
if [ ! -f ${DIR_DATA}/contours.txt ] ; then
	cp ${DIR_DATA}/contours.default.txt ${DIR_DATA}/contours.txt
fi

# Create pbf files for topo
echo -e "${Yel}Downloading hgt files and creating correspondent pbf files...${RCol}";
cd ${DIR_CT}
rm -f *.pbf 
phyghtmap -j ${PHY_MAX_JOBS} \
 --step=${PHY_MINOR_LINE} \
 --line-cat=${PHY_MAJOR_LINE},${PHY_MEDIUM_LINE} \
 --polygon=${DIR_POLY}/${AREA}.poly \
 --pbf \
 --output-prefix=contour \
 --hgtdir=${DIR_HGT}

# Création du fichier .img contenant seulement les données OSM à partir des morceaux découpés
echo -e "${Yel}Creating the gmapsupp.img topo file with mkgmap...${RCol}";
cd ${DIR_CTO}
ls | grep -v '.gitignore' | xargs rm -f
java -Xmx${JAVA_XMX} -jar ${DIR_BIN}/mkgmap/mkgmap.jar \
 --max-jobs=${MKGMAP_MAX_JOBS} \
 --keep-going \
 --gmapsupp \
 --mapname="${MAP_NAME}" \
 --description="${AREA_NAME}" \
 --area-name="${AREA_NAME}" \
 --country-name="${AREA_NAME}" \
 --country-abbr="${AREA_CODE}" \
 --precomp-sea=${DIR_DATA}/sea_${SEA_VERSION}.zip \
 --read-config=${DIR_STYLE}/options \
 --style-file=${DIR_STYLE} \
 --remove-ovm-work-files=${TO_MERGE} \
 ${DIR_DATA}/contours.txt ${DIR_CT}/*.pbf

# Rename and save the gmapsupp.img file
if [ -f gmapsupp.img ] ; then
	mkdir -p ${DIR_IMG}/${AREA}
	mv gmapsupp.img ${DIR_IMG}/${AREA}/${AREA}-topo.img
	echo -e "${Gre}You can find your img file here : ${DIR_IMG}/${AREA}/${AREA}-topo.img ${RCol}";
else
	echo -e "${Red}gmapsupp.img file not found !${RCol}"
fi

# Show time elapsed
TIME_END=$(date +%s)
TIME_DIFF=$(($TIME_END - $TIME_START));
echo -e "${Whi}Total time elapsed : "`displaytime "$TIME_DIFF"`"${RCol}"
