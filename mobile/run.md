Trong terminal, vào thư mục mobile rồi chạy:
C:\Users\FPT\flutter\bin\flutter.bat emulators --launch Pixel_9_Pro
C:\Users\FPT\flutter\bin\flutter.bat devices
Khi emulator hiện trong danh sách, chạy app bằng device ID Flutter vừa báo, thường là emulator-5554:
C:\Users\FPT\flutter\bin\flutter.bat run -d emulator-5554 --dart-define-from-file=client.env.json
