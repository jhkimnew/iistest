﻿using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using System;
using System.IO;
using System.Threading.Tasks;

namespace BlobTransfer
{
    public static class Program
    {
        private const string TransferReportNamePrefix = "report";
        private const int ERROR_BAD_ARGUMENTS = 0xA0;

        public static async Task Main(string[] args)
        {

            //ToDo: Clean project file to remove unused references
            //ToDo: Create Cancelation token with timeout 20 minutes to force this program exit in 20 minutes

            var loggerFactory = LoggerFactory.Create(builder =>
                {
                    builder.AddConsole();
                });

            var logger = loggerFactory.CreateLogger("Program");

            if (!InitializeBlobTransfer(logger))
            {
                return;
            }

            var config = GetConfig();
            var configuration = config.GetSection("BlobTransfer").Get<BlobTransferConfiguration>();

            var report = new TransferReport();
            var worker = new BlobTransferWorker(configuration, loggerFactory);

            await worker.RunAsync(report);
            await WriteFileAsync(TransferReportNamePrefix, report);

            logger.LogInformation("Done!");
        }

        private static IConfiguration GetConfig()
        {
            var configBuilder = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .AddEnvironmentVariables();

            var config = configBuilder.Build();

            return config;
        }

        private static bool InitializeBlobTransfer(ILogger logger)
        {
            bool result = true;

            BlobTransferWorker.SourceSasUriSecretFilePath = Environment.ExpandEnvironmentVariables("%BlobTrasferSourceSasUriSecretFilePath%");
            BlobTransferWorker.TargetSasUriSecretFilePath = Environment.ExpandEnvironmentVariables("%BlobTrasferTargetSasUriSecretFilePath%");

            if (string.IsNullOrEmpty(BlobTransferWorker.SourceSasUriSecretFilePath) ||
                string.IsNullOrEmpty(BlobTransferWorker.TargetSasUriSecretFilePath))
            {
                logger.LogError("Environment variable 'BlobTrasferSourceSasUriSecretFilePath' or 'BlobTrasferTargetSasUriSecretFilePath' is not set. Program exits.");
                Environment.ExitCode = ERROR_BAD_ARGUMENTS;
                result = false;
            }

            if (result && !File.Exists(BlobTransferWorker.SourceSasUriSecretFilePath) ||
                !File.Exists(BlobTransferWorker.TargetSasUriSecretFilePath))
            {
                logger.LogError($"{BlobTransferWorker.SourceSasUriSecretFilePath} or {BlobTransferWorker.SourceSasUriSecretFilePath} not found. Program exits.");
                Environment.ExitCode = ERROR_BAD_ARGUMENTS;
                result = false;
            }

            if (result &&  string.IsNullOrEmpty(BlobTransferWorker.GetSourceSasUri()) ||
                string.IsNullOrEmpty(BlobTransferWorker.GetTargetSasUri()))
            {
                logger.LogError("Failed to get SourceSasUri or TargetSasUri. Program exits.");
                Environment.ExitCode = ERROR_BAD_ARGUMENTS;
                result = false;
            }

            return result;
        }

        private async static Task WriteFileAsync(string fileNamePrefix, object data)
        {
            string suffix = string.Format("{0:yyyy-MM-dd_HH-mm-ss-fff}", DateTimeOffset.Now);
            var fileName = fileNamePrefix + "_" + suffix + ".json";
            await File.WriteAllTextAsync(fileName, JsonConvert.SerializeObject(data, Formatting.Indented));
        }
    }
}
