FROM mcr.microsoft.com/dotnet/core/runtime:3.1 AS base
WORKDIR /app
COPY bin/Debug/netcoreapp3.1/publish/ .
EXPOSE 80
ENTRYPOINT ["dotnet", "BlobTransfer.dll"]
#
# Clone git
#     mkdir ~/gitroot
#     cd ~/gitroot
#     git clone https://github.com/jhkimnew/iistest.git
#
# How to update blobtransfersecretfile.json
#     Run below two commands to generate sas tokens 
#       az storage container generate-sas --name export --account-name mcrdevtransfer --expiry 2021-01-01 --permissions acdlrw --https-only --output tsv --subscription "MCR - TEST"
#       az storage container generate-sas --name exportussec --account-name mcrdevtransfer --expiry 2021-01-01 --permissions acdlrw --https-only --output tsv --subscription "MCR - TEST"
#     Open ~/gitroot/iistest/temp/BlobTransfer/src/secret/blobtransfersecretfile.json with notepad
#     Replace *** with the generated tokens and save the updated file
#
# How to run this program
#     mkdir ~/gitroot
#     cd ~/gitroot
#     git clone https://github.com/jhkimnew/iistest.git
#     cd ~/gitroot/iistest/temp/BlobTransfer/src
#     dotnet publish
#     docker build -t jhkimnew/transferblob .
#     docker run -v ~/gitroot/iistest/temp/BlobTransfer/src/secret:/secret --env BlobTrasferSourceSasUriSecretFilePath=/secret/blobtransfersecretfile.json --env BlobTrasferTargetSasUriSecretFilePath=/secret/blobtransfersecretfile.json --rm jhkimnew/transferblob
#