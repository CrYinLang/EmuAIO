from PIL import Image
import os

# 获取当前目录下的所有文件
for filename in os.listdir('.'):
    if filename.endswith('.png'):
        img = Image.open(filename)
        img = img.resize((256, 256))
        img.save(filename)