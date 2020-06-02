using Microsoft.Azure.Storage;
using Microsoft.Azure.Storage.Blob;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.IO;
using System.Threading.Tasks;

namespace BlobTransfer
{
    public class BlobTransferWorker
    {
        public static string SourceSasUriSecretFilePath;
        public static string TargetSasUriSecretFilePath;

        private readonly BlobTransferConfiguration _identityConfiguration;
        private readonly ILogger<BlobTransferWorker> _logger;
        private readonly ILoggerFactory _loggerFactory;
        private BlobCopier _blobCopier;

        public static string GetSourceSasUri()
        {
            var secretFile = JsonConvert.DeserializeObject<SecretFile>(File.ReadAllText(SourceSasUriSecretFilePath));
            return secretFile.SourceSasUri;
        }

        public static string GetTargetSasUri()
        {
            var secretFile = JsonConvert.DeserializeObject<SecretFile>(File.ReadAllText(TargetSasUriSecretFilePath));
            return secretFile.TargetSasUri;
        }

        public BlobTransferWorker(
            BlobTransferConfiguration identityConfiguration,
            ILoggerFactory loggerFactory)
        {
            _identityConfiguration = identityConfiguration ?? throw new ArgumentNullException(nameof(identityConfiguration));
            _loggerFactory = loggerFactory ?? throw new ArgumentNullException(nameof(loggerFactory));
            _logger = _loggerFactory.CreateLogger<BlobTransferWorker>();

            var sourceContainerSas = new Uri(GetSourceSasUri());
            var targetContainerSas = new Uri(GetTargetSasUri());
            _blobCopier = new BlobCopier(sourceContainerSas, targetContainerSas, _logger);
        }

        private static async Task ListBlobsFlatListingAsync(CloudBlobContainer container, int? segmentSize)
        {
            BlobContinuationToken continuationToken = null;
            CloudBlob blob;

            try
            {
                // Call the listing operation and enumerate the result segment.
                // When the continuation token is null, the last segment has been returned
                // and execution can exit the loop.
                do
                {
                    BlobResultSegment resultSegment = await container.ListBlobsSegmentedAsync(string.Empty,
                        true, BlobListingDetails.Metadata, segmentSize, continuationToken, null, null);

                    foreach (var blobItem in resultSegment.Results)
                    {
                        // A flat listing operation returns only blobs, not virtual directories.
                        blob = (CloudBlob)blobItem;

                        // Write out some blob properties.
                        Console.WriteLine("Blob name: {0}", blob.Name);
                    }

                    Console.WriteLine();

                    // Get the continuation token and loop until it is null.
                    continuationToken = resultSegment.ContinuationToken;

                } while (continuationToken != null);
            }
            catch (StorageException e)
            {
                Console.WriteLine(e.Message);
                Console.ReadLine();
                throw;
            }
        }

        public async Task RunAsync(TransferReport transferReport)
        {
            var container = _blobCopier.GetSourceContainer();
            BlobContinuationToken continuationToken = null;

            try
            {
                //
                // Enumerate the result segment for the source blobs in order to copy each blob.
                // When the continuation token is null, the last segment has been returned and exit the loop.
                //
                do
                {
                    BlobResultSegment resultSegment = await container.ListBlobsSegmentedAsync(
                        string.Empty,                   // prefix
                        true,                           // useFlatBlobListing
                        BlobListingDetails.Metadata,    // blobListingDetails
                        null,                           // maxResults
                        continuationToken,              // currentToken
                        null,                           // options
                        null);                          // operationContext

                    foreach (var blobItem in resultSegment.Results)
                    {
                        //
                        // Copy each blob
                        //
                        CloudBlob blob = (CloudBlob)blobItem;
                        await CopyBlob(blob, transferReport);
                    }

                    // Get the continuation token and loop until it is null.
                    continuationToken = resultSegment.ContinuationToken;

                } while (continuationToken != null);
            }
            catch (StorageException e)
            {
                _logger.LogWarning($"Failed to copy blobs. HTTP error code {e.RequestInformation.HttpStatusCode}: {e.RequestInformation.ErrorCode}");
                throw;
            }

            _logger.LogInformation($"Total blobs successfully copied: {transferReport.CopyBlobs.Succeeded.Count}.");
            _logger.LogInformation($"Total blobs skipped: {transferReport.CopyBlobs.Skipped.Count}.");
            _logger.LogInformation($"Total blobs failed in copying: {transferReport.CopyBlobs.Failed.Count}.");
        }

        private async Task CopyBlob(CloudBlob blob, TransferReport transferReport)
        {
            string blobName = blob.Name;
            string blobUri = blob.Uri.AbsoluteUri;

            transferReport.ListSourceBlob.Succeeded.Add(blobName);
            try
            {
                Tuple<bool, string> tupleResult = await _blobCopier.GetContentMD5(blobName);

                bool succeededToGetContentMD5 = tupleResult.Item1;
                var contentMD5 = tupleResult.Item2;

                if (!succeededToGetContentMD5)
                {
                    _logger.LogError($"Failed to copy: {blobUri}");
                    transferReport.CopyBlobs.Failed.Add(blobName);
                    return;
                }

                if (String.IsNullOrEmpty(contentMD5))
                {
                    _logger.LogDebug($"Skip to copy: {blobUri}");
                    transferReport.CopyBlobs.Skipped.Add(blobName);
                    return;
                }

                _logger.LogInformation($"Begin to copy: {blobUri}:{contentMD5}");
                await _blobCopier.SetMetadata(blobName, "mcrexport", contentMD5);
                await _blobCopier.CopyAsync(blobName);
                _logger.LogInformation($"End to copy: {blobUri}:{contentMD5}");

                transferReport.CopyBlobs.Succeeded.Add(blobName);
            }
            catch (Exception e)
            {
                transferReport.CopyBlobs.Failed.Add(blobName);
                _logger.LogError($"Blob {blobName}: failed to copy, unexpected exception: {e.ToString()}.");
            }
        }

    }
}
