# Declaration Reporting
Jamf Pro currently lacks observability around declarations made via Blueprints, specifically Software Updates. In order to help mitigate this, the following workflow was developed. Please bear in mind that this is primarily a PoC and while it works fine in a test server, I'm not certain how well it will scale as it does the `Log Show` during each recon.

## Primary Design
- The `Last Declaration Report.sh` is added as an Extension Attribute. It runs a `log show` command looking for the most recent declaration report for Software Updates in the last day. Once found, it outputs the information to a .json and reports the last run as mm/dd/yyyy hh:mm:ss (make sure to configure the Extension Attribute so that it knows it's a date format as this will be crucial in any reporting you setup). 
- All of the .sh scripts in the repo that start with "Software Update" are added as Extension Attributes. They read from `/var/log/update_declarations.json` and report the value of each
- Values are updated each inventory update

## Problem Areas
- I'm not sure if a race condition will develop with the reports. I would recommend creating the `Last Declaration Report` EA first and then all the supporting EAs. As far as I know, EAs run sequentially during an inventory update so they _should_ not have a race condition but further testing is always a good idea.
- NULL entries will result in nothing reported in the EA, this is working as intended.

## Disclaimer 
None of this is an official Jamf or Apple workflow. It's best to Query the API endpoint that Jamf designed for this purpose ($url/api/v1/ddm/$foundMgmtID/status-items) which will report the same information. The problem this is designed to fix is to be able to get more fleet wide information in an easy to manage report. However, the API is the most accurate reporting of these items and this workflow can potentially be behind since it's not recommended to update inventory more than once a day and DDM status updates happen more often than that.

## Documentation
To better understand what the values reported are, please reference [Apple's Documentation](https://support.apple.com/guide/deployment/phases-of-apple-software-update-enforcement-dep225c4b7d4/web)
