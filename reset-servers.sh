# Stop/shut down all containers
sudo docker stop $(sudo docker ps --format {{.Names}} | grep jupyter)

# Remove containers 
sudo docker rm $(sudo docker ps -aq)

# Remove .julia directories 
for d in /tank/home/*; do
  echo "cleaing $d"
  cd $d && sudo rm -rf .julia .jupyter .local .ipython
done

