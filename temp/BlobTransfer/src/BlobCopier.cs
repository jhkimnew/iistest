using Microsoft.Azure.Storage;
using Microsoft.Azure.Storage.Blob;
using Microsoft.Azure.Storage.DataMovement;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace BlobTransfer
{
    public class BlobCopier
    {
        private readonly ILogger _logger;
        private readonly CloudBlobContainer _sourceContainer;
        private readonly CloudBlobContainer _targetContainer;

        public BlobCopier(
            Uri sourceContainerSas,
            Uri targetContainerSas,
            ILogger logger)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _sourceContainer = new CloudBlobContainer(sourceContainerSas);
            _targetContainer = new CloudBlobContainer(targetContainerSas);
        }

        public CloudBlobContainer GetSourceContainer()
        {
            var result = _sourceContainer.ServiceClient.GetContainerReference("export");
            return result;
        }

        public async Task CopyAsync(string blobName, CancellationToken token = default(CancellationToken))
        {
            var sourceBlob = _sourceContainer.GetBlobReference(blobName);
            var targetBlob = _targetContainer.GetBlobReference(blobName);
            TransferCheckpoint checkpoint = null;
            SingleTransferContext context = GetSingleTransferContext(checkpoint, blobName);

            try
            {
                await TransferManager.CopyAsync(
                    sourceBlob: sourceBlob,
                    destBlob: targetBlob,
                    copyMethod: CopyMethod.ServiceSideAsyncCopy,
                    options: null,
                    context: context,
                    cancellationToken: token);
            }
            catch (UnauthorizedAccessException)
            {
                _logger.LogInformation($"Failed to copy blob. You don't have permission to copy");
                throw;
            }
        }

        public async Task SetMetadata(string blobName, string metadataName, string metadataValue)
        {
            var sourceBlob = _sourceContainer.GetBlobReference(blobName);
            try
            {
                // Add mcrexport metadata with the contentMD5 value to indicate this blob is already copied.
                sourceBlob.Metadata[metadataName] = metadataValue;
                await sourceBlob.SetMetadataAsync();
            }
            catch (StorageException e)
            {
                _logger.LogInformation($"Failed to set metadata. {blobName}:{metadataName}:{metadataValue}, HTTP error code {e.RequestInformation.HttpStatusCode}: {e.RequestInformation.ErrorCode}");
                throw;
            }
        }

        public async Task<Tuple<bool, string>> GetContentMD5(string blobName, CancellationToken token = default(CancellationToken))
        {
            bool succeededToGetContentMD5 = false;
            string contentMD5 = null;
            const string mcrexportMetadataName = "mcrexport";
            var sourceBlob = _sourceContainer.GetBlobReference(blobName);

            try
            {
                await sourceBlob.FetchAttributesAsync();

                if (sourceBlob.Properties == null)
                {
                    throw new ArgumentException("Blob properties is null");
                }

                if (String.IsNullOrEmpty(sourceBlob.Properties.ContentMD5))
                {
                    throw new ApplicationException("ContentMD5 is not available");
                }

                succeededToGetContentMD5 = true;
                if (sourceBlob.Metadata.ContainsKey(mcrexportMetadataName))
                {
                    if (sourceBlob.Metadata[mcrexportMetadataName] != sourceBlob.Properties.ContentMD5)
                    {
                        _logger.LogDebug($"Blob {blobName}: metadata {mcrexportMetadataName} found but value does not match {sourceBlob.Metadata[mcrexportMetadataName]}: {sourceBlob.Properties.ContentMD5}");
                        contentMD5 = sourceBlob.Properties.ContentMD5;
                    }
                    else
                    {
                        _logger.LogDebug($"Blob {blobName}: already copied, contentMD5: {sourceBlob.Properties.ContentMD5}");
                    }
                }
                else
                {
                    _logger.LogDebug($"Blob {blobName}: succeeded to get contentMD5 attribute");
                    contentMD5 = sourceBlob.Properties.ContentMD5;
                }
            }
            catch (StorageException e)
            {
                _logger.LogWarning($"Blob {blobName}: failed to fetch ContentMD5 attribute. HTTP error code {e.RequestInformation.HttpStatusCode}: {e.RequestInformation.ErrorCode}");
            }
            catch (Exception e)
            {
                _logger.LogWarning($"Blob {blobName}: failed to get ContentMD5 attribute, exception: {e.ToString()}.");
            }

            return new Tuple<bool, string>(succeededToGetContentMD5, contentMD5);
        }

        private SingleTransferContext GetSingleTransferContext(TransferCheckpoint checkpoint, string blobName)
        {
            SingleTransferContext context = new SingleTransferContext(checkpoint);

            context.ShouldOverwriteCallbackAsync = TransferContext.ForceOverwrite;

            context.ProgressHandler = new Progress<TransferStatus>((progress) =>
            {
                _logger.LogDebug($"{blobName}: bytes transferred {progress.BytesTransferred}.");
            });

            return context;
        }
    }
}