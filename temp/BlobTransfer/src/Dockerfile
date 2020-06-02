FROM mcr.microsoft.com/dotnet/core/runtime:3.1 AS base
WORKDIR /app
COPY bin/Debug/netcoreapp3.1/publish/ .
EXPOSE 80
ENTRYPOINT ["dotnet", "BlobTransfer.dll"]
#
# 1. Clone this git to build. Adjust the path as you want.
#     mkdir ~/gitroot
#     cd ~/gitroot
#     git clone <git clone path>
#
# 2. Update secret/blobtransfersecretfile.json file.
#     2.1 Get the sas token for both source and target with executing az cli like the below examples
#       az storage container generate-sas --name export --account-name mcrdevtransfer --expiry 2021-01-01 --permissions acdlrw --https-only --output tsv --subscription "MCR - TEST"
#       az storage container generate-sas --name exportussec --account-name mcrdevtransfer --expiry 2021-01-01 --permissions acdlrw --https-only --output tsv --subscription "MCR - TEST"
#     2.2 Open the ~/gitroot/iistest/temp/BlobTransfer/src/secret/blobtransfersecretfile.json and adjust the sas uri
#         and then replace *** with actual token value and save the file
#
# 3. Run this program with executing the below commands.
#     mkdir ~/gitroot
#     cd ~/gitroot
#     git clone https://github.com/jhkimnew/iistest.git
#     cd ~/gitroot/iistest/temp/BlobTransfer/src
#     dotnet publish
#     docker build -t jhkimnew/transferblob .
#     docker run -v ~/gitroot/iistest/temp/BlobTransfer/src/secret:/secret --env BlobTrasferSourceSasUriSecretFilePath=/secret/blobtransfersecretfile.json --env BlobTrasferTargetSasUriSecretFilePath=/secret/blobtransfersecretfile.json --rm jhkimnew/transferblob
#