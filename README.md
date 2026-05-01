# GoEnum
Web enumeration script using tools written in Go (plus NMap) for TCM Security's PEH course. This is an (updated) iteration of Gr1mmie's sumrecon without the non-Go-based tools (third-level subdomain, whatweb, and EyeWitness). This has been tested in Kali Linux and Ubuntu distros.

This needs to be executed as `sudo` within the current environment since it automatically checks and installs the dependencies, including Go:
```
sudo -E ./goenum.sh
```

## Dependencies
- AssetFinder: https://github.com/tomnomnom/assetfinder
- AMass v4.2.0: https://github.com/owasp-amass/amass
- HttProbe: https://github.com/tomnomnom/httprobe
- SubJack: https://github.com/haccer/subjack
- WaybackURLs: https://github.com/tomnomnom/waybackurls

## Additional Notes
Later versions of amass (5.0.0) has known issues so the script will check for and downgrade to v4.2.0. Additionally, golang version is currently hardcoded to v1.26.2.
