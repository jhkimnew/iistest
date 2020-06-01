namespace BlobTransfer
{
    public class TransferReport
    {
        public TransferResult ListSourceBlob { get; set; } = new TransferResult();
        public TransferResult CopyBlobs { get; set; } = new TransferResult();
    }
}
