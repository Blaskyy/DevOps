package main

import (
	"encoding/json"
	"fmt"
	"github.com/anvie/port-scanner"
	"gopkg.in/mgo.v2"
	//"time"
	//"gopkg.in/mgo.v2/bson"
	"io/ioutil"
	"net/http"
)

const JNUM = 100
const WNUM = 5

type Iports struct {
	Ip     string
	Opened []int
	//Update string
}

type Host struct {
	Ip string
}

type AllHost struct {
	Ips []Host
}

//workers
func worker(id int, jobs <-chan string, c *mgo.Collection, results chan<- bool) {
	for j := range jobs {
		fmt.Printf("Worker #%d is scanning IP: %s\n", id, j)
		scanOne(j, c)
		results <- true
	}
	//return
}

//scan jobs
func scanOne(ip string, c *mgo.Collection) {
	//time.Sleep(time.Second)
	//fmt.Println("Scanning IP:", ip)
	ps := portscanner.NewPortScanner(ip)
	openedPorts := ps.GetOpenedPort(22, 53)
	c.Insert(&Iports{ip, openedPorts})
	//return
}

func main() {
	//connect to mongodb
	session, err := mgo.Dial("")
	if err != nil {
		panic(err)
	}
	defer session.Close()
	session.SetMode(mgo.Monotonic, true)

	//select collection
	c := session.DB("golang").C("iports")

	//parse url
	dat, err := ioutil.ReadFile("../url")
	response, err := http.Get(string(dat))
	defer response.Body.Close()
	body, err := ioutil.ReadAll(response.Body)
	var ips AllHost
	json.Unmarshal(body, &ips)

	//allocate jobs
	jobs := make(chan string, len(ips.Ips))
	results := make(chan bool, len(ips.Ips))
	for w := 1; w <= WNUM; w++ {
		go worker(w, jobs, c, results)
	}

	//send jobs
	for _, j := range ips.Ips {
		//fmt.Println(j.Ip)
		jobs <- j.Ip
	}
	close(jobs)
	for i := 1; i <= len(ips.Ips); i++ {
		<-results
	}
}
