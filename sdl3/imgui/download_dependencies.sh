mkdir -p ./.dependencies/shared
cd ./.dependencies/shared
git clone https://gitlab.com/L-4/odin-imgui.git odin-imgui
cd odin-imgui
python3 build.py