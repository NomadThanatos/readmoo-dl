# Readmoo EPUB 下載工具

本專案僅為學習 Ruby 使用，並不負責他人使用本工具造成的任何侵權問題。

## 使用方法
1. 安裝 Ruby 2.4 以上，3.0 以下，安装Chrome或修改[此處](https://github.com/NomadThanatos/readmoo-dl/blob/master/lib/readmoo_dl/API.rb#L43)為您的瀏覽器

2. 安裝 Bundle

    ``` gem install bundler ```

3. 在專案根目錄下執行套件安裝

    ``` bundle install ```

4. 複製 main.rb.example 到專案根目錄，並且改名為 main.rb，複製 history.txt.example 到專案根目錄，並且改名為 history.txt
    
    ``` mv main.rb.example main.rb ```
   
    ``` mv history.txt.example history.txt ```
    
5. 依照 main.rb 裡面的說明修改程式

6. 在終端機中執行下方程式開始下載
    
    ``` bundle exec ruby main.rb ```
