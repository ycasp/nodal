require "grover"

Grover.configure do |config|
  config.options = {
    format: "A4",
    margin: {
      top: "20mm",
      bottom: "20mm",
      left: "15mm",
      right: "15mm"
    },
    print_background: true,
    launch_args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu"
    ]
  }

  chrome_path = if Rails.env.development?
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  else
    ENV["GOOGLE_CHROME_BIN"] || ENV["PUPPETEER_EXECUTABLE_PATH"] || ENV["GOOGLE_CHROME_SHIM"]
  end

  config.options[:executable_path] = chrome_path if chrome_path.present?
end
