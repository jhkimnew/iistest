/*
For Ubutu OS, 
1) Install dotnet core (https://dotnet.microsoft.com/download/linux-package-manager/ubuntu16-04/sdk-current)
2) Clone this repo
3) update SENDGRID_API_KEY of Properties\launchSettings.json with the valid value
4) run "sudo dotnet run --launch-profile test".
 */
using System;
using System.Threading.Tasks;
using SendGrid;
using SendGrid.Helpers.Mail;

namespace jhkimnewsendgridconsole
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Hello World!");
            Execute().Wait();
        }

        static async Task Execute() {
            var apiKey = Environment.GetEnvironmentVariable("SENDGRID_API_KEY");
            Console.WriteLine("Key [" + apiKey + "]");
            Console.WriteLine("JHKIM_ENV [" + Environment.GetEnvironmentVariable("JHKIM_ENV") + "]");
            var client = new SendGridClient(apiKey);
            var from = new EmailAddress("jhkim@microsoft.com", "Jeong Hwan Kim");
            var to = new EmailAddress("jhkim@microsoft.com", "Jeong Hwan Kim");
            var subject = "Sending with Twilio SendGrid is fun!";
            var plainTextContent = "and easy to do anywhere";
            var htmlContent = "<string> and easy to use html tag</string>";
            var msg = MailHelper.CreateSingleEmail(
                from,
                to,
                subject,
                plainTextContent,
                htmlContent
            );

            var response = await client.SendEmailAsync(msg);
        }
    }
}
