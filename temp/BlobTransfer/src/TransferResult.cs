using System.Collections.Generic;

namespace BlobTransfer
{
    public class TransferResult
    {
        public List<string> Succeeded { get; set; } = new List<string>();
        public List<string> Skipped { get; set; } = new List<string>();
        public List<string> Failed { get; set; }  = new List<string>();
    }
}
