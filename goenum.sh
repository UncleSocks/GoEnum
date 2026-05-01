#!/bin/bash

DOMAIN=$1
DIR=$DOMAIN/recon
OUTPUT=$DIR/final.txt
ALIVE=$DIR/alive.txt

AF_OUT=$DIR/afinder.txt
AMASS_OUT=$DIR/amass.txt
SUBJACK_OUT=$DIR/takeover.txt

NMAP_DIR=$DIR/nmap
NMAP_OUT=$NMAP_DIR/scan.txt

WAYBACK_DIR=$DIR/wayback
WAYBACK_OUT=$WAYBACK_DIR/wayback.txt
WB_PARAMS_OUT=$WAYBACK_DIR/wayback_params.txt
WB_EXT_DIR=$WAYBACK_DIR/extensions



function check_dependencies() {
        echo [+] Checking whether Go is installed...
        if [ ! "$(command -v go)" ]; then
                echo [-] Go needs to be installed. Attempting to install golang...
                wget https://go.dev/dl/go1.26.2.linux-amd64.tar.gz
                echo [+] Deleting current installations of go...
                rm -rf /usr/local/go
                tar -C /usr/local -xzf go1.26.2.linux-amd64.tar.gz

                echo [+] Adding go to PATH...
                export PATH=$PATH:/usr/local/go/bin
                export PATH=$PATH:$(go env GOPATH)/bin

        fi
        echo [+] Go is present in the system. Checking required Go-based tools...

        if [ ! "$(command -v assetfinder)" ]; then
                echo [-] assetfinder not installed in the system.
                echo [+] Attempting to download and install assetfinder...
                go install github.com/tomnomnom/assetfinder@latest
        fi
        echo [+] assetfinder found..

        if [ ! "$(command -v amass)" ] ||  [ "$(amass --version 2>&1)" != "v4.2.0" ]; then
                echo [-] amass v4.2.0  not installed in the system.
                echo [+] Attempting to download and install amass...
                go install -v github.com/owasp-amass/amass/v4/...@master

                if [ "$(amass --version 2>&1)" != "v4.2.0" ]; then
                        echo [-] amass running is not version 4.2.0.
                        echo [-] Attempting to remove newer version of amass installed via apt...
                        apt remove -y amass
                fi

        fi
        echo [+] amass v4.2.0 found.

        if [ ! "$(command -v httprobe)" ]; then
                echo [-] httprobe not installed in the system...
                echo [+] Attempting to download and install httprobe...
                go install github.com/tomnomnom/httprobe@latest
        fi
        echo [+] httprobe found.

        if [ ! "$(command -v subjack)" ]; then
                echo [-] subjack not installed in the system...
                echo [+] Attempting to download and install subjack...
                go install github.com/haccer/subjack@latest
        fi
        echo [+] subjack found.

        if [ ! "$(command -v waybackurls)" ]; then
                echo [-] waybackurls not installed in the system...
                echo [+] Attempting to download and install waybackurls
                go install github.com/tomnomnom/waybackurls@latest
        fi
        echo [+] waybackurls found.
}

echo [+] Checking dependencies...
check_dependencies
echo [+] Dependency check complete.


if [ ! -d $DOMAIN ]; then
        mkdir $DOMAIN
fi

if [ ! -d "$DIR" ]; then
        mkdir $DIR
fi

echo [+] Harvesting subdomains with assetfinder...
assetfinder $DOMAIN >> $AF_OUT
echo [+] Raw assetfinder output saved at $AF_OUT

echo [+] Filtering and cleaning assetfinder output...
grep $DOMAIN $AF_OUT >> $OUTPUT

# Amass version 4.2.0 is used since newer version has issues when enumerating subdomains.
echo [+] Harvesting additional subdomains with amass...
amass enum -d $DOMAIN -o $AMASS_OUT
echo [+] Raw amass output saved at $AMASS_OUT

echo [+] Collating amass result with assetfinder...
awk '{print $1}' $AMASS_OUT | sed 's/\x1b\[[0-9;]*m//g' | grep "$DOMAIN\$" | sort -u >> $OUTPUT
echo [+] Sorting collated subdomain output...
sort -u -o $OUTPUT $OUTPUT

echo [+] Checking for live subdomains with httprobe...
cat $OUTPUT | httprobe | awk -F '://' '{print $2}' >> $ALIVE
echo [+] Sorting and de-duplicating httprobe output...
sort -u -o $ALIVE $ALIVE

# Starting version 3.0.0 of subjack, the configuration JSON file has been embedded in the binary.
echo [+] Checking for possible subdomain takeover with subjack....
subjack -w $OUTPUT -t 100 -timeout 30 -ssl -v 3 -o $SUBJACK_OUT

#echo [+] Scanning open ports with nmap...
#if [ ! -d $NMAP_DIR ]; then
#       mkdir $NMAP_DIR
#fi
#nmap -iL $OUTPUT -T4 -oN $NMAP_OUT

echo [+] Scraping wayback data...
if [ ! -d $WAYBACK_DIR ]; then
        mkdir $WAYBACK_DIR
fi
cat $OUTPUT | waybackurls >> $WAYBACK_OUT
echo [+] Removing blank entries...
sed -i '/^[[:space:]]*$/d' $WAYBACK_OUT

echo [+] Parsing and compiling all possible params found in wayback data...
awk -F '=' '/.*=/ {printf "%s=\n",$1}' $WAYBACK_OUT | sort -u >> $WB_PARAMS_OUT

echo [+] Parsing and compiling js/php/aspx/jsp/json files from wayback data...
if [ ! -d $WB_EXT_DIR ]; then
        mkdir $WB_EXT_DIR
fi

JS_OUT=$WB_EXT_DIR/js.txt
PHP_OUT=$WB_EXT_DIR/php.txt
ASPX_OUT=$WB_EXT_DIR/aspx.txt
JSP_OUT=$WB_EXT_DIR/jsp.txt
JSON_OUT=$WB_EXT_DIR/json.txt

while IFS= read -r line; do
        ext="${line##*.}"

        case $ext in
                "js") echo $line >> $JS_OUT | sort -o $JS_OUT $JS_OUT;;
                "php") echo $line >> $PHP_OUT | sort -o $PHP_OUT $PHP_OUT;;
                "asp") echo $line >> $ASP_OUT | sort -o $ASPX_OUT $ASPX_OUT;;
                "jsp") echo $line >> $JSP_OUT | sort -o $JSP_OUT $JSP_OUT;;
                "json") echo $line >> $JSON_OUT | sort -o $JSON_OUT $JSON_OUT;;
        esac
done < $WAYBACK_OUT

echo [+] Enumeration of $DOMAIN domain complete
