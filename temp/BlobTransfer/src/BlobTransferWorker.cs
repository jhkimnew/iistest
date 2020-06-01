using Microsoft.Azure.Storage;
using Microsoft.Azure.Storage.Blob;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
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

        private async Task CopyBlob()
        {

        }

        public async Task RunAsync(
            TransferReport transferReport
        )
        {
            //
            // You can get the list of blob with running
            // az storage blob list --container export --account-name mcrdevtransfer --subscription "MCR - Test" --query [*].name
            //
            //string[] blobsExportSucceeded = new string[] {
            //    "mcrflowdev/hello-world-export:latest-sha256:34d7629ce2e4f9b812564eebdf55d8c6bb2e9078fcc2d7ececb1c6cf92283541",
            //    "staging/mcrflowdev/hello-world-export:latest-sha256:34d7629ce2e4f9b812564eebdf55d8c6bb2e9078fcc2d7ececb1c6cf92283541",
            //    "test.txt"
            //};
            var sourceContainerSas = new Uri(GetSourceSasUri());
            var targetContainerSas = new Uri(GetTargetSasUri());
            var blobCopier = new BlobCopier(sourceContainerSas, targetContainerSas, _logger);
            var container = blobCopier.GetSourceContainer();

            BlobContinuationToken continuationToken = null;
            CloudBlob blob;

            try
            {
                // Call the listing operation and enumerate the result segment.
                // When the continuation token is null, the last segment has been returned
                // and execution can exit the loop.
                do
                {
                    BlobResultSegment resultSegment = await container.ListBlobsSegmentedAsync(
                        string.Empty,
                        true,
                        BlobListingDetails.Metadata,
                        null,                           //  maxResults
                        continuationToken,
                        null,                           // options
                        null);                          // operationContext

                    foreach (var blobItem in resultSegment.Results)
                    {
                        blob = (CloudBlob)blobItem;

                        var blobName = blob.Name;

                        transferReport.ListSourceBlob.Succeeded.Add(blobName);
                        try
                        {
                            Tuple<bool, string> tupleResult = await blobCopier.GetContentMD5(blobName);

                            bool succeededToGetContentMD5 = tupleResult.Item1;
                            var contentMD5 = tupleResult.Item2;

                            if (!succeededToGetContentMD5)
                            {
                                transferReport.CopyBlobs.Failed.Add(blobName);

                                continue;
                            }

                            if (String.IsNullOrEmpty(contentMD5))
                            {
                                transferReport.CopyBlobs.Skipped.Add(blobName);

                                continue;
                            }

                            _logger.LogInformation($"Blob {blobName}: Start to Copy");

                            await blobCopier.CopyAsync(blobName, contentMD5);

                            _logger.LogInformation($"Blob {blobName}: Completed to copy");

                            transferReport.CopyBlobs.Succeeded.Add(blobName);
                        }
                        catch (Exception e)
                        {
                            transferReport.CopyBlobs.Failed.Add(blobName);
                            _logger.LogError($"Blob {blobName}: failed to copy, unexpected exception: {e.ToString()}.");
                        }
                    }

                    // Get the continuation token and loop until it is null.
                    continuationToken = resultSegment.ContinuationToken;

                } while (continuationToken != null);
            }
            catch (StorageException e)
            {
                _logger.LogWarning($"Failed to list blobs. HTTP error code {e.RequestInformation.HttpStatusCode}: {e.RequestInformation.ErrorCode}");
                throw;
            }

            // ToDo: Retry failed blob

            _logger.LogInformation($"Total blobs successfully copied: {transferReport.CopyBlobs.Succeeded.Count}.");
            _logger.LogInformation($"Total blobs skipped: {transferReport.CopyBlobs.Skipped.Count}.");
            _logger.LogInformation($"Total blobs failed in copying: {transferReport.CopyBlobs.Failed.Count}.");
        }
    }
}
