using System;

namespace BlobTransfer
{
    public class BlobTransferConfiguration
    {
        public string ClientId { get; set; }
        public string ClientSecret { get; set; }
        public string AadEndpoint { get; set; }
        public string ArmEndpoint { get; set; }
        public string ArmResourceUri { get; set; }
        public string SourceContainerSasUri { get; set; }
        public string DestinationContainerSasUri { get; set; }

        public void Validate()
        {
            if (string.IsNullOrWhiteSpace(ClientId))
            {
                throw new ArgumentException(nameof(ClientId));
            }

            if (string.IsNullOrWhiteSpace(ClientSecret))
            {
                throw new ArgumentException(nameof(ClientSecret));
            }

            if (string.IsNullOrWhiteSpace(SourceContainerSasUri))
            {
                throw new ArgumentException($"{nameof(SourceContainerSasUri)} is required.");
            }

            if (string.IsNullOrWhiteSpace(DestinationContainerSasUri))
            {
                throw new ArgumentException($"{nameof(DestinationContainerSasUri)} is required.");
            }
        }
    }
}