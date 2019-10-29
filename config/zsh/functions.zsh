# Run Docker Compose file in local directory
compose () {
    function on_exit {
        docker-compose stop
        docker-compose kill
        docker-compose rm -vf
    }
    
    trap on_exit EXIT
    
    docker-compose kill
    docker-compose rm -vf
    docker-compose build
    docker-compose up --remove-orphans
}
