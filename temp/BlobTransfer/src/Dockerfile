FROM mcr.microsoft.com/dotnet/core/runtime:3.1 AS base
WORKDIR /app
COPY bin/Debug/netcoreapp3.1/publish/ .
EXPOSE 80
ENTRYPOINT ["dotnet", "BlobTransfer.dll"]
#
# How to run this program
# docker run -v ./secret:/secret --env BlobTrasferSourceSasUriSecretFilePath=/secret/blobtransfersecretfile.json BlobTrasferTargetSasUriSecretFilePath=/secret/blobtransfersecretfile.json --rm jhkimnew/transferblob
#