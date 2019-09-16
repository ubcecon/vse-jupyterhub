# Stop/shut down all containers
sudo docker stop $(sudo docker ps --format {{.Names}} | grep jupyter)

# Remove .julia directories 
for d in /tank/home/*; do
  echo "cleaing $d"
  sudo rm -rf d/.julia
done

# Remove containers 
sudo docker rm $(sudo docker ps -aq)
