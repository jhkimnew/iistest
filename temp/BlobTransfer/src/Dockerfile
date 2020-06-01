FROM mcr.microsoft.com/dotnet/core/runtime:3.1 AS base
WORKDIR /app
COPY bin/Debug/netcoreapp3.1/publish/ .
EXPOSE 80
ENTRYPOINT ["dotnet", "BlobTransfer.dll"]
#
# How to run this program
#     docker run -v ./secret:/secret --env BlobTrasferSourceSasUriSecretFilePath=/secret/blobtransfersecretfile.json BlobTrasferTargetSasUriSecretFilePath=/secret/blobtransfersecretfile.json --rm jhkimnew/transferblob
# 
# How to generate sas token for the sas ui for source and target
#     az storage container generate-sas --name export --account-name mcrdevtransfer --expiry 2021-01-01 --permissions acdlrw --https-only --output tsv --subscription "MCR - TEST"
#     az storage container generate-sas --name exportussec --account-name mcrdevtransfer --expiry 2021-01-01 --permissions acdlrw --https-only --output tsv --subscription "MCR - TEST"
#